
// https://github.com/dappuniversity/nft_marketplace
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

// import { ERC721, ERC721Permit } from "@soliditylabs/erc721-permit/contracts/ERC721Permit.sol";

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


contract NFTMarketplaceV2 is ReentrancyGuard {

    // store axelar receiver address (for execution verification)
    address operator;

    // Variables
    address payable public immutable feeAccount; // the account aka marketplace owner that receives fees
    uint public feePercent; // the fee percentage on sales
    uint public itemCount;

    // use token to purchase nft instead of native coin
    address receivingToken;

    struct Item {
        uint itemId;
        IERC721 nft;
        uint tokenId;
        uint price;
        address payable seller;
        uint expiryOn;
        bool sold;
    }

    // itemId -> Item
    mapping(uint => Item) public items;

    event Offered(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        uint expiryOn
    );

    event Bought(
        uint itemId,
        address indexed nft,
        uint tokenId,
        uint price,
        address indexed seller,
        address indexed buyer
    );

    event Delist(
        uint itemId,
        uint delistOn
    );

    constructor(uint _feePercent, address _operator, address _receivingToken) {
        feeAccount = payable(msg.sender);
        feePercent = _feePercent;
        operator = _operator;
        receivingToken = _receivingToken;
    }

    function getMarketplaceFee() public view returns (uint) {
        return feePercent;
    }

    function getItemCount() public view returns (uint) {
        return itemCount;
    }

    function updateMarketplaceFee(uint _newFee) public {
        require(feeAccount == msg.sender, "Only owner can update operator");
        require(_newFee >= 0 && _newFee <= 100, "Invalid marketplace fee (must be in between of 0~100%)");
        feePercent = _newFee;
    }

    function getOperator() public view returns (address) {
        return operator;
    }

    function updateOperator(address _operator) public {
        require(feeAccount == msg.sender, "Only owner can update operator");
        operator = _operator;
    }


    function getOwner() public view returns (address) {
        return feeAccount;
    }

    // shared function for cross chain and same chain call
    function _makeItem(IERC721 _nft, uint _tokenId, uint _price, uint _expiryOn, address _seller) private nonReentrant {
        require(_nft.ownerOf(_tokenId) == _seller, 'Only nft owner can access this function');
        require(_price > 0, "Price must be greater than zero");
        require(_expiryOn > block.timestamp, "Invalid expiry time");
        // increment itemCount
        itemCount ++;
        // transfer nft
        _nft.transferFrom(_seller, address(this), _tokenId);
        // add new item to items mapping
        items[itemCount] = Item (
            itemCount,
            _nft,
            _tokenId,
            _price,
            payable(_seller),
            _expiryOn,
            false
        );
        // emit Offered event
        emit Offered(
            itemCount,
            address(_nft),
            _tokenId,
            _price,
            _seller,
            _expiryOn
        );
    }

    // Make item to offer on the marketplace
    function makeItem(IERC721 _nft, uint _tokenId, uint _price, uint _expiryOn) external nonReentrant {
        _makeItem(_nft, _tokenId, _price, _expiryOn, msg.sender);
    }

    // Cross Chain Make item to offer on the marketplace
    function crossMakeItem(IERC721 _nft, uint _tokenId, uint _price, uint _expiryOn, address _seller) external {
        require(msg.sender == operator, "Only operator can access this function");
       _makeItem(_nft, _tokenId, _price, _expiryOn, _seller);
    }

    // same chain purchase
    function purchaseItem(uint _itemId) external nonReentrant {
        uint _totalPrice = getTotalPrice(_itemId);
        Item storage item = items[_itemId];
        require(_itemId > 0 && _itemId <= itemCount, "item doesn't exist");
        require(!item.sold, "item already sold");
        require(item.expiryOn > block.timestamp, "item listing expired");

        // check if buyer have enough balance to pay
        IERC20 axlToken = IERC20(receivingToken);

        // user allowance
        uint256 userAllowance = axlToken.allowance(address(msg.sender), address(this));
        // check for allowance
        require(userAllowance > 0, 'Insufficient usdc allowance');
        require(axlToken.balanceOf(msg.sender) >= _totalPrice, 'Insufficient payment');

        // pay seller and feeAccount
        // item.seller.transfer(item.price);
        // feeAccount.transfer(_totalPrice - item.price);

        //Transfer the proceeds from the sale to the seller of the NFT
        axlToken.transferFrom(msg.sender, item.seller, item.price);
        // payable(seller).transfer(msg.value);

        //Transfer the listing fee to the marketplace creator
        axlToken.transferFrom(msg.sender, feeAccount, _totalPrice - item.price);

        // update item to sold
        item.sold = true;

        // transfer nft to buyer
        item.nft.transferFrom(address(this), msg.sender, item.tokenId);

        // emit Bought event
        emit Bought(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            msg.sender
        );
    }

    // cross chain purchnase
    function crossPurchaseItem(uint _itemId, address _buyer) external {
        require(msg.sender == operator, "Only operator can access this function");

        Item storage item = items[_itemId];

        // transfer nft to buyer
        item.nft.transferFrom(address(this), _buyer, item.tokenId);

        // emit Bought event
        emit Bought(
            _itemId,
            address(item.nft),
            item.tokenId,
            item.price,
            item.seller,
            _buyer
        );
    }

    // shared function to delist item using offer expiry time (cross chain / same chain)
    function _delistItem(uint _itemId, address _seller) private nonReentrant {
        Item storage item = items[_itemId];
        require(item.seller == _seller, "Only nft owner can access this function");
        item.expiryOn = block.timestamp;

        emit Delist(
            _itemId,
            item.expiryOn
        );
    }

    // same chain delist
    function delistItem(uint _itemId) external nonReentrant {
        _delistItem(_itemId, msg.sender);
    }

    // cross chain delist
    function crossDelistItem(uint _itemId, address _seller) external {
        Item storage currentItem = items[_itemId];

        require(msg.sender == operator, "Only operator can access this function");
        require(currentItem.seller == _seller, "Only owner can delist item");

        _delistItem(_itemId, _seller);
    }

    //This will return all the holder NFTs currently listed to be sold on the marketplace
    function getHolderListedNFTs(address holder) public view returns (Item[] memory) {
        Item[] memory tokens = new Item[](itemCount);
        uint currentIndex = 0;

        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for(uint i=0;i<itemCount;i++)
        {
            uint currentId = i + 1;
            Item storage currentItem = items[currentId];

            // listing date valid
            // seller = holder
            // item not sold yet
            if (currentItem.expiryOn > block.timestamp && currentItem.seller == holder && !currentItem.sold) {
                // get listed item only
                tokens[currentIndex] = currentItem;
            }

            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    //This will return all the holder NFTs currently listed to be sold on the marketplace
    function getAllListedNFTs() public view returns (Item[] memory) {
        Item[] memory tokens = new Item[](itemCount);
        uint currentIndex = 0;

        //at the moment currentlyListed is true for all, if it becomes false in the future we will
        //filter out currentlyListed == false over here
        for(uint i=0;i<itemCount;i++)
        {
            uint currentId = i + 1;
            Item storage currentItem = items[currentId];

            // listing date valid
            // item not sold yet
            if (currentItem.expiryOn > block.timestamp && !currentItem.sold) {
                // get listed item only
                tokens[currentIndex] = currentItem;
            }

            currentIndex += 1;
        }
        //the array 'tokens' has the list of all NFTs in the marketplace
        return tokens;
    }

    // get particular listed nft details (price, etc)
    function getListedItem(uint256 _itemId) public view returns (Item memory) {
        Item storage currentItem = items[_itemId];
        Item memory returnItem = items[_itemId];

        if (currentItem.expiryOn > block.timestamp && !currentItem.sold) {
            returnItem = currentItem;
        }

        return returnItem;
    }

    function getTotalPrice(uint _itemId) view public returns(uint){
        return((items[_itemId].price*(100 + feePercent))/100);
    }
}