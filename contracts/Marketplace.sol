// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Marketplace is ReentrancyGuard {
    
    //@title NFT Marketplace
    //@author Pankaj Jagtap
    //@dev All function calls are currently implemented without any side effects

    IERC20 private jaggu;

    address payable public immutable adminAccount;
    uint public platformFeePercent = 25; // the fee percentage on sales = 2.5% = 25/1000
    uint public itemCount;  // Current items for sale
    uint public itemsSold; // Total items sold

    // 3 Events - After Listing, after Cancelling Listing, after Selling Item
    event ItemListed(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint sellingPrice,
        address indexed seller
    );

    event ItemCancelled(
        uint itemId,
        address indexed seller,
        address indexed nft
    );

    event ItemSold(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint sellingPrice,
        address indexed seller,
        address indexed buyer
    );

    struct Item {
        uint itemId;
        IERC721 nftContract;
        uint tokenId;
        uint sellingPrice;
        address payable NFTdesigner;
        address payable seller;
        bool isFirstSale;
        bool sold;
    }

    mapping(uint => Item) public itemIdToItemMap; // itemId to item mapping
    mapping(uint => address[]) private itemIdToRoyaltyOwners; //itemId to array of royalty Owners mapping
    mapping(uint => uint[]) private itemIdtoRoyaltyPercent; // itemId to corresponding Royaly Percentages mapping

    // @notice Setting royalty owners and corresponding royalty percent
    // @dev Will check if msg.sender is the designer of the NFT

    function setRoyaltyOwnersAndPercent(uint _itemId, address[] memory royaltyOwners, uint[] memory royaltyPercent) 
    public {
        Item storage item = itemIdToItemMap[_itemId];
        require(item.seller == msg.sender && item.NFTdesigner == msg.sender, "You need to be the NFT designer and current owner of the NFT item");
        itemIdToRoyaltyOwners[_itemId] = royaltyOwners;
        itemIdtoRoyaltyPercent[_itemId] = royaltyPercent;
    }

    // @notice Calculating the royalty that would have to be paid
    // @param It will take item id, sellling Price and index of address for which royalty is to be calculated

    function calculateRoyaltyFees(uint _itemId, uint sellingPrice, uint index) public view returns(uint _royalty) {
        uint _royaltyPercent = itemIdtoRoyaltyPercent[_itemId][index];
        return _royalty = (sellingPrice * _royaltyPercent)/1000; 
    }

    constructor(address _token) {
        jaggu = IERC20(_token);
        adminAccount = payable(msg.sender);
    }

    // @notice Listing Item on Marketplace.
    // @dev It will confirm if you are the owner of the NFT item
    // @param It will take ERC721 NFTcontractaddress, tokenid, expected Selling Price, expected Royalty Percent

    function listItem (IERC721 _NFT, uint _tokenId, uint _sellingPrice) external nonReentrant {
        require(_NFT.ownerOf(_tokenId) == msg.sender, "You are not the owner, so can't sell");
        require(_sellingPrice > 0, "Price has to be greater than zero");
        
        itemCount++;
        
        itemIdToItemMap[itemCount] = Item (
            itemCount,
            _NFT,
            _tokenId,
            _sellingPrice,
            payable(msg.sender),
            payable(msg.sender),
            true,
            false
        );

        _NFT.transferFrom(msg.sender, address(this), _tokenId);
        
        emit ItemListed(itemCount, address(_NFT), _tokenId, _sellingPrice, msg.sender);
    }

    // @notice Cancelling the Listing from Marketplace.
    // @dev It will confirm if you are currently the owner of the NFT item
    // @param It will take item id

    function cancelListing (uint _itemId) external nonReentrant {
        Item storage item = itemIdToItemMap[_itemId];
        require(item.seller == msg.sender, "You are not the owner of the NFT item");

        delete itemIdToItemMap[_itemId];
        itemCount--;

        emit ItemCancelled(_itemId, msg.sender, address(item.nftContract));
    }

    // @notice Buying items from Marketplace.
    // @dev It will confirm if you have enough Jaggu Tokens to buy, if the item exists and is the item not sold
    // @param It will take item id

    function buyItem (uint _itemId) external payable nonReentrant {
        Item storage item = itemIdToItemMap[_itemId];

        uint256 _sellingPrice = item.sellingPrice;
        uint256 _platformFees = calculatePlatformFees(_sellingPrice);
        uint _amount = _sellingPrice - _platformFees;

        require(jaggu.balanceOf(msg.sender) >= _sellingPrice, "You don't Have Token To purchase Nft");
        require(_itemId > 0 && _itemId <= itemCount, "Item does not exist");
        require(item.sold == false, "Item has already been sold");

        if (item.isFirstSale == true) {
            jaggu.transferFrom(msg.sender, adminAccount, _platformFees); // transfer platform fees
            jaggu.transferFrom(msg.sender, item.seller, _amount); // transfer selling price to owner
        } else if (item.isFirstSale == false) {
            uint _totalRoyaltySent;
            uint _index = itemIdToRoyaltyOwners[_itemId].length;

            for (uint i=0; i<_index; i++) {
                uint _individualRoyalty = calculateRoyaltyFees(_sellingPrice, _itemId, i);
                jaggu.transferFrom(msg.sender, itemIdToRoyaltyOwners[_itemId][i], _individualRoyalty);
                _totalRoyaltySent += _individualRoyalty;
            }
            jaggu.transferFrom(msg.sender, item.seller, (_amount - _totalRoyaltySent));
            item.nftContract.transferFrom(item.seller, msg.sender, item.tokenId);
        }

        item.sold = true;
        itemCount--;
        itemsSold++;

        item.nftContract.transferFrom(address(this), msg.sender, item.tokenId);
        item.seller = payable(msg.sender);

        emit ItemSold( _itemId, address(item.nftContract), item.tokenId, item.sellingPrice, item.seller, msg.sender );
    }

    // @notice Calculate platform fees you have to pay
    // @dev return the platform fees
    // @param the selling price to be paid 

    function calculatePlatformFees(uint256 _amount) internal view returns (uint256 _price) {
        return _price = (_amount * platformFeePercent) / 1000;
    }
}