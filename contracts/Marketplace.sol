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
        address NFTcreator;
        address seller;
        bool isFirstSale;
        bool sold;
    }

    mapping(uint256 => Item) public itemIdToItemMap; // itemId to item mapping
    mapping(uint256 => address[]) public itemIdToRoyaltyOwners; //itemId to array of royalty Owners mapping
    mapping(uint256 => uint256[]) public itemIdtoRoyaltyPercent; // itemId to corresponding Royaly Percentages mapping
    mapping(address => uint256) public royaltyOwnerBalances; // address to royalty balance mapping

    constructor(address _token) {
        jaggu = IERC20(_token);
        adminAccount = msg.sender;
    }

    // @notice Setting royalty owners and corresponding royalty percent
    // @dev Will check if msg.sender is the designer of the NFT

    function setRoyaltyOwnersAndPercent(
        uint256 _itemId,
        address[] memory royaltyOwners,
        uint256[] memory royaltyPercent
    ) public {
        Item storage item = itemIdToItemMap[_itemId];
        require(item.seller == msg.sender && item.NFTcreator == msg.sender, "You need to be the NFT designer and current owner of the NFT item");
        itemIdToRoyaltyOwners[_itemId] = royaltyOwners;
        itemIdtoRoyaltyPercent[_itemId] = royaltyPercent;
    }

    // @notice Calculating the royalty that would have to be paid
    // @param It will take item id, sellling Price and index of address for which royalty is to be calculated

    function updateBalancesforRoyalties(uint256 _itemId, uint256 _sellingPrice)
        internal
        returns (uint256)
    {
        uint256 _arrLength = itemIdToRoyaltyOwners[_itemId].length;
        uint256 _totalRoyaltyAmount;

        for (uint256 i = 0; i < _arrLength; i++) {
            address _recepient = itemIdToRoyaltyOwners[_itemId][i];
            uint256 _fee = itemIdtoRoyaltyPercent[_itemId][i];

            uint256 _amount = (_sellingPrice * _fee) / 10000;

            royaltyOwnerBalances[_recepient] += _amount;
            _totalRoyaltyAmount += _amount;
        }
        return _totalRoyaltyAmount;
    }

    function claimRoyalties() external {
        require(royaltyOwnerBalances[msg.sender] > 0, "No royalty earned");
        jaggu.transferFrom(
            address(this),
            payable(msg.sender),
            royaltyOwnerBalances[msg.sender]
        );
    }

    // @notice Listing Item on Marketplace.
    // @dev It will confirm if you are the owner of the NFT item
    // @param It will take ERC721 NFT contract address, tokenId, expected Selling Price

    function listItem(
        IERC721 _NFT,
        uint256 _tokenId,
        uint256 _sellingPrice
    ) external nonReentrant {
        require(_NFT.ownerOf(_tokenId) == msg.sender,"You are not the owner, so can't sell");
        require(_sellingPrice > 0, "Price has to be greater than zero");

        itemId++;

        itemIdToItemMap[itemId] = Item(
            itemId,
            _NFT,
            _tokenId,
            _sellingPrice,
            msg.sender,
            msg.sender,
            true,
            false
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
        require(item.seller == msg.sender,"You are not the owner of the NFT item");

        delete itemIdToItemMap[_itemId];

        emit ItemCancelled(_itemId, msg.sender, address(item.nftContract));
    }

    // @notice Buying items from Marketplace.
    // @dev It will confirm if you have enough Jaggu Tokens to buy, if the item exists and is the item not sold
    // @param It will take item id

    function buyItem(uint256 _itemId) external payable nonReentrant {
        Item storage item = itemIdToItemMap[_itemId];

        uint256 _sellingPrice = item.sellingPrice;
        uint256 _platformFees = calculatePlatformFees(_sellingPrice);
        uint256 _amount = _sellingPrice - _platformFees;

        require(jaggu.balanceOf(msg.sender) >= _sellingPrice,"You don't Have Token To purchase Nft");
        require(_itemId > 0 && _itemId <= itemId, "Item does not exist");
        require(item.sold == false, "Item has already been sold");

        if (item.isFirstSale == true) {
            jaggu.transferFrom(msg.sender,payable(adminAccount),_platformFees); // transfer platform fees
            jaggu.transferFrom(msg.sender, payable(item.seller), _amount); // transfer selling price to owner
        } else {
            uint256 _totalRoyaltyAmount = updateBalancesforRoyalties(_itemId,_sellingPrice);

            jaggu.transferFrom(msg.sender,payable(adminAccount),_platformFees); // transfer platform fees

            jaggu.transferFrom(msg.sender,payable(item.seller),(_amount - _totalRoyaltyAmount)); // transfer left price to owner

            item.nftContract.transferFrom(item.seller,payable(msg.sender),item.tokenId);
        }

        delete itemIdToItemMap[_itemId];
        itemsSold++;

        item.nftContract.transferFrom(address(this),payable(msg.sender), item.tokenId);

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

    function calculatePlatformFees(uint256 _amount)
        internal
        view
        returns (uint256 _price)
    {
        return _price = (_amount * platformFeePercent) / 10000;
    }
}
