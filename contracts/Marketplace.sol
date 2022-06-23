// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./NFT.sol";

contract Marketplace is NFT, ReentrancyGuard {
    //@title NFT Marketplace
    //@author Pankaj Jagtap
    //@dev All function calls are currently implemented without any side effects

    IERC20 private jaggu;

    address public immutable adminAccount;
    uint256 public platformFeePercent = 250; // the fee percentage on sales = 2.5% = 250/10000
    uint256 private itemId;
    uint256 public itemsSold; // Total items sold

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
        address[] memory royaltyOwners,
        uint256[] memory royaltyPercent
    ) external {
        require(
            creatorToTokenCount[msg.sender] == _tokenId,
            "You need to be the NFT creator of the NFT item"
        );
        require(
            royaltyOwners.length < 6,
            "Maximum royalty owners can only be 5"
        );
        require(
            royaltyOwners.length == royaltyPercent.length,
            "Total royalty owners should be equal to corresponding royalty percentages"
        );

        uint256 _totalRoyaltyPercent;

        for (uint256 i = 0; i < royaltyPercent.length; i++) {
            _totalRoyaltyPercent += royaltyPercent[i];
        }

        if (_totalRoyaltyPercent > 10) {
            revert();
        }

        itemIdToRoyaltyInfo[_itemId].royaltyOwners = royaltyOwners;
        itemIdToRoyaltyInfo[_itemId].royaltyPercent = royaltyPercent;
    }

    // Function to claim Royalties

    function claimRoyalties() external payable {
        require(royaltyOwnerBalances[msg.sender] > 0, "No royalty earned");
        jaggu.transferFrom(
            address(this),
            payable(msg.sender),
            royaltyOwnerBalances[msg.sender]
        );
        royaltyOwnerBalances[msg.sender] -= msg.value;
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

        itemId++;

        itemIdToItemMap[itemId] = Item(
            itemId,
            _NFT,
            _tokenId,
            _sellingPrice,
            msg.sender
        );

        _NFT.transferFrom(msg.sender, address(this), _tokenId);

        emit ItemListed(
            itemId,
            address(_NFT),
            _tokenId,
            _sellingPrice,
            msg.sender
        );
    }

    // @notice Cancelling the Listing from Marketplace.
    // @dev It will confirm if you are currently the owner of the NFT item
    // @param It will take item id

    function cancelListing(uint256 _itemId) external nonReentrant {
        Item memory item = itemIdToItemMap[_itemId];
        require(
            item.seller == msg.sender,
            "You are not the owner of the NFT item"
        );

        emit ItemCancelled(_itemId, msg.sender, address(item.nftContract));

        delete itemIdToItemMap[_itemId];
    }

    // @notice Buying items from Marketplace.
    // @dev It will confirm if you have enough Jaggu Tokens to buy, if the item exists and is the item not sold
    // @param It will take item id

    function buyItem(uint256 _itemId) external payable nonReentrant {
        Item storage item = itemIdToItemMap[_itemId];

        uint256 _sellingPrice = item.sellingPrice;
        uint256 _platformFees = _calculatePlatformFees(_sellingPrice);
        uint256 _amount = _sellingPrice - _platformFees;

        require(
            jaggu.balanceOf(msg.sender) >= _sellingPrice,
            "You don't have sufficient Jaggu Tokens this purchase Item"
        );
        require(_itemId > 0 && _itemId <= itemId, "Item does not exist");

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

        item.nftContract.transferFrom(
            address(this),
            payable(msg.sender),
            item.tokenId
        ); // transfer NFT from smart contract to buyer

        itemsSold++;

        emit ItemSold(
            _itemId,
            address(item.nftContract),
            item.tokenId,
            item.sellingPrice,
            item.seller,
            msg.sender
        );
        delete itemIdToItemMap[_itemId];
    }

    // @notice Calculate platform fees you have to pay
    // @dev return the platform fees
    // @param the selling price to be paid

    function _calculatePlatformFees(uint256 _amount)
        internal
        view
        returns (uint256 _price)
    {
        return _price = (_amount * platformFeePercent) / 10000;
    }

    // @notice Calculating the royalty that would have to be paid
    // @param It will take item id, sellling Price and index of address for which royalty is to be calculated

    function _updateBalancesforRoyalties(uint256 _itemId, uint256 _sellingPrice)
        internal
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
