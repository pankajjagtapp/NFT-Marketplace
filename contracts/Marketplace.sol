// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NFT.sol";

contract Marketplace is NFT, ReentrancyGuard {
    //@title NFT Marketplace
    //@author Pankaj Jagtap
    //@dev All function calls are currently implemented without any side effects

    using Counters for Counters.Counter;
    Counters.Counter public itemId;
    Counters.Counter public itemsSold; // Total items sold

    IERC20 private jaggu;

    address public immutable adminAccount;
    uint256 public platformFeePercent = 250; // the fee percentage on sales = 2.5% = 250/10000

    // 3 Events - After Listing, after Cancelling Listing, after Selling Item
    event ItemListed(
        uint256 itemId,
        address indexed nft,
        uint256 tokenId,
        uint256 sellingPrice,
        address indexed seller
    );

    event ItemCancelled(
        uint256 itemId,
        address indexed seller,
        address indexed nft
    );

    event ItemSold(
        uint256 itemId,
        address indexed nft,
        uint256 tokenId,
        uint256 sellingPrice,
        address indexed seller,
        address indexed buyer
    );

    // modifier to check if item is up for sale

    modifier itemIdExists(uint256 _itemId) {
        uint256 currentItemId = itemId.current();
        require(_itemId > 0 && _itemId <= currentItemId, "Item does not exist");
        _;
    }

    struct Item {
        uint256 itemId;
        IERC721 nftContract;
        uint256 tokenId;
        uint256 sellingPrice;
        address seller;
    }

    // Struct for Royalty Owners and corresponding Royalty Percent
    struct RoyaltyInfo {
        uint256[] royaltyPercent;
        address[] royaltyOwners;
    }

    mapping(uint256 => Item) public itemIdToItemMap; // itemId to item mapping
    mapping(uint256 => RoyaltyInfo) private itemIdToRoyaltyInfo; //itemId to Struct of corresponding royalty mapping
    mapping(address => uint256) public royaltyOwnerBalances; // address to royalty balance mapping

    constructor(address _token) {
        jaggu = IERC20(_token);
        adminAccount = msg.sender;
    }

    // @notice Setting royalty owners and corresponding royalty percent
    // @dev Will check if msg.sender is the designer of the NFT

    function setRoyaltyOwnersAndPercent(
        uint256 _tokenId,
        uint256 _itemId,
        address[] memory _royaltyOwners,
        uint256[] memory _royaltyPercent
    ) external itemIdExists(_itemId) {
        require(
            tokenCountToCreator[_tokenId] == msg.sender,
            "You need to be the NFT creator of the NFT item"
        );
        require(
            _royaltyOwners.length < 6,
            "Maximum royalty owners can only be 5"
        );
        require(
            _royaltyOwners.length == _royaltyPercent.length,
            "Total royalty owners should be equal to corresponding royalty percentages"
        );

        uint256 _totalRoyaltyPercent;

        for (uint256 i = 0; i < _royaltyPercent.length; i++) {
            _totalRoyaltyPercent += _royaltyPercent[i];
        }
        require(
            _totalRoyaltyPercent < 10,
            "Total royalty percentage should be less than 10%"
        );

        itemIdToRoyaltyInfo[_itemId].royaltyOwners = _royaltyOwners;
        itemIdToRoyaltyInfo[_itemId].royaltyPercent = _royaltyPercent;
    }

    // Function to claim Royalties

    function claimRoyalties() external {
        require(royaltyOwnerBalances[msg.sender] > 0, "No royalty earned");
        jaggu.transferFrom(
            address(this),
            payable(msg.sender),
            royaltyOwnerBalances[msg.sender]
        );
        royaltyOwnerBalances[msg.sender] = 0;
    }

    // @notice Listing Item on Marketplace.
    // @dev It will confirm if you are the owner of the NFT item
    // @param It will take ERC721 NFT contract address, tokenId, expected Selling Price

    function listItem(
        IERC721 _NFT,
        uint256 _tokenId,
        uint256 _sellingPrice
    ) external nonReentrant {
        require(
            _NFT.ownerOf(_tokenId) == msg.sender,
            "You are not the owner, so can't sell"
        );
        require(_sellingPrice > 0, "Price has to be greater than zero");

        itemId.increment();
        uint256 _itemId = itemId.current();

        itemIdToItemMap[_itemId] = Item(
            _itemId,
            _NFT,
            _tokenId,
            _sellingPrice,
            msg.sender
        );

        _NFT.safeTransferFrom(msg.sender, address(this), _tokenId);

        emit ItemListed(
            _itemId,
            address(_NFT),
            _tokenId,
            _sellingPrice,
            msg.sender
        );
    }

    // @notice Cancelling the Listing from Marketplace.
    // @dev It will confirm if you are currently the owner of the NFT item
    // @param It will take item id

    function cancelListing(uint256 _itemId)
        external
        nonReentrant
        itemIdExists(_itemId)
    {
        Item memory item = itemIdToItemMap[_itemId];
        require(
            item.seller == msg.sender,
            "You are not the owner of the NFT item"
        );

        delete itemIdToItemMap[_itemId];

        emit ItemCancelled(_itemId, msg.sender, address(item.nftContract));
    }

    // @notice Buying items from Marketplace.
    // @dev It will confirm if you have enough Jaggu Tokens to buy, if the item exists and is the item not sold
    // @param It will take item id

    function buyItem(uint256 _itemId)
        external
        payable
        itemIdExists(_itemId)
        nonReentrant
    {
        Item memory item = itemIdToItemMap[_itemId];

        uint256 _sellingPrice = item.sellingPrice;
        uint256 _platformFees = _calculatePlatformFees(_sellingPrice);
        uint256 _amount = _sellingPrice - _platformFees;

        require(
            jaggu.balanceOf(msg.sender) >= _sellingPrice,
            "You don't have sufficient Jaggu Tokens this purchase Item"
        );

        uint256 _totalRoyaltyAmount = _updateBalancesforRoyalties(
            _itemId,
            _sellingPrice
        );

        jaggu.transferFrom(
            msg.sender,
            payable(adminAccount),
            _platformFees + _totalRoyaltyAmount
        ); // transfer platform fees

        jaggu.transferFrom(
            msg.sender,
            payable(item.seller),
            (_amount - _totalRoyaltyAmount)
        ); // transfer left price to owner

        item.nftContract.safeTransferFrom(
            address(this),
            payable(msg.sender),
            item.tokenId
        ); // transfer NFT from smart contract to buyer

        itemsSold.increment();

        delete itemIdToItemMap[_itemId];

        emit ItemSold(
            _itemId,
            address(item.nftContract),
            item.tokenId,
            item.sellingPrice,
            item.seller,
            msg.sender
        );
    }

    // @notice Calculate platform fees you have to pay
    // @dev return the platform fees
    // @param the selling price to be paid

    function _calculatePlatformFees(uint256 _amount)
        internal
        view
        returns (uint256 _price)
    {
        _price = (_amount * platformFeePercent) / 10000;
    }

    // @notice Calculating the royalty that would have to be paid
    // @param It will take item id, sellling Price and index of address for which royalty is to be calculated

    function _updateBalancesforRoyalties(uint256 _itemId, uint256 _sellingPrice)
        internal
        itemIdExists(_itemId)
        returns (uint256)
    {
        RoyaltyInfo memory royaltyInfo = itemIdToRoyaltyInfo[_itemId];
        uint256 _arrLength = royaltyInfo.royaltyOwners.length;
        uint256 _totalRoyaltyAmount;

        for (uint256 i = 0; i < _arrLength; i++) {
            address _recepient = royaltyInfo.royaltyOwners[i];
            uint256 _fee = royaltyInfo.royaltyPercent[i];

            uint256 _amount = (_sellingPrice * _fee) / 10000;

            royaltyOwnerBalances[_recepient] += _amount;
            _totalRoyaltyAmount += _amount;
        }
        return _totalRoyaltyAmount;
    }
}
