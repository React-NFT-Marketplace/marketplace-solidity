
// https://github.com/dappuniversity/nft_marketplace
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface OneNFT{
    // empty because we're not concerned with internal details
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFromWithPermit(address from, address to, uint256 tokenId, uint256 deadline, bytes memory signature) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function approve(address to, uint256 tokenId) external;
}

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
        address nft;
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

    function getItemCount() external view returns (uint) {
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


    function getOwner() external view returns (address) {
        return feeAccount;
    }

    // shared function for cross chain and same chain call
    function _makeItem(address _nft, uint _tokenId, uint _price, uint _expiryOn, address _seller, uint sigExpiry, bytes memory signature) private {
        OneNFT targetNFT = OneNFT(_nft);

        require(targetNFT.ownerOf(_tokenId) == _seller, 'Only nft owner can access this function');
        require(_price > 0, "Price must be greater than zero");
        require(_expiryOn > block.timestamp, "Invalid expiry time");
        // increment itemCount
        itemCount ++;
        // transfer nft
        targetNFT.safeTransferFromWithPermit(_seller, address(this), _tokenId, sigExpiry, signature);
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
            _nft,
            _tokenId,
            _price,
            _seller,
            _expiryOn
        );
    }

    // Make item to offer on the marketplace
    function makeItem(address _nft, uint _tokenId, uint _price, uint _expiryOn, uint sigExpiry, bytes memory signature) external {
        _makeItem(_nft, _tokenId, _price, _expiryOn, msg.sender, sigExpiry, signature);
    }

    // Cross Chain Make item to offer on the marketplace
    function crossMakeItem(address _nft, uint _tokenId, uint _price, uint _expiryOn, address _seller, uint sigExpiry, bytes memory signature) external {
        require(msg.sender == operator, "Only operator can access this function");
       _makeItem(_nft, _tokenId, _price, _expiryOn, _seller, sigExpiry, signature);
    }

    // same chain purchase
    function purchaseItem(uint _itemId) external nonReentrant {
        uint _totalPrice = getTotalPrice(_itemId);
        require(_itemId > 0 && _itemId <= itemCount, "item doesn't exist");
        require(!items[_itemId].sold, "item already sold");
        require(items[_itemId].expiryOn > block.timestamp, "item listing expired");

        // check if buyer have enough balance to pay
        IERC20 axlToken = IERC20(receivingToken);

        // user allowance
        uint256 userAllowance = axlToken.allowance(address(msg.sender), address(this));
        // check for allowance
        require(userAllowance > 0, 'Insufficient usdc allowance');
        require(axlToken.balanceOf(msg.sender) >= _totalPrice, 'Insufficient payment');

        // pay seller and feeAccount
        // items[_itemId].seller.transfer(items[_itemId].price);
        // feeAccount.transfer(_totalPrice - items[_itemId].price);

        //Transfer the proceeds from the sale to the seller of the NFT
        axlToken.transferFrom(msg.sender, items[_itemId].seller, items[_itemId].price);
        // payable(seller).transfer(msg.value);

        //Transfer the listing fee to the marketplace creator
        axlToken.transferFrom(msg.sender, feeAccount, _totalPrice - items[_itemId].price);

        // update item to sold
        items[_itemId].sold = true;

        // transfer nft to buyer
        OneNFT targetNFT = OneNFT(items[_itemId].nft);
        targetNFT.transferFrom(address(this), msg.sender, items[_itemId].tokenId);

        // emit Bought event
        emit Bought(
            _itemId,
            items[_itemId].nft,
            items[_itemId].tokenId,
            items[_itemId].price,
            items[_itemId].seller,
            msg.sender
        );
    }

    // cross chain purchnase
    function crossPurchaseItem(uint _itemId, address _buyer) external {
        require(msg.sender == operator, "Only operator can access this function");

        // transfer nft to buyer
        OneNFT targetNFT = OneNFT(items[_itemId].nft);
        targetNFT.approve(_buyer, items[_itemId].tokenId);
        targetNFT.transferFrom(address(this), _buyer, items[_itemId].tokenId);

        // update item to sold
        items[_itemId].sold = true;

        // emit Bought event
        emit Bought(
            _itemId,
            items[_itemId].nft,
            items[_itemId].tokenId,
            items[_itemId].price,
            items[_itemId].seller,
            _buyer
        );
    }

    // shared function to delist item using offer expiry time (cross chain / same chain)
    function _delistItem(uint _itemId, address _seller) private {
        require(items[_itemId].seller == _seller, "Only nft owner can access this function");
        items[_itemId].expiryOn = block.timestamp;

        //approve the marketplace to sell NFTs on your behalf
        OneNFT targetNFT = OneNFT(items[_itemId].nft);
        targetNFT.transferFrom(address(this), items[_itemId].seller, items[_itemId].tokenId);

        emit Delist(
            _itemId,
            items[_itemId].expiryOn
        );
    }

    // same chain delist
    function delistItem(uint _itemId) external nonReentrant {
        _delistItem(_itemId, msg.sender);
    }

    // cross chain delist
    function crossDelistItem(uint _itemId, address _seller) external {
        require(msg.sender == operator, "Only operator can access this function");
        require(items[_itemId].seller == _seller, "Only owner can delist item");

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
    function getListedItem(uint256 _itemId) external view returns (Item memory) {
        Item storage currentItem = items[_itemId];
        Item memory returnItem;

        if (currentItem.expiryOn > block.timestamp && !currentItem.sold) {
            returnItem = currentItem;
        }

        return returnItem;
    }

    function getTotalPrice(uint _itemId) view public returns(uint){
        return((items[_itemId].price*(100 + feePercent))/100);
    }
}