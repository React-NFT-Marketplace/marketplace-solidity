//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";
import {AxelarExecutable} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/executables/AxelarExecutable.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

//The structure to store info about a listed token
struct Item {
    uint itemId;
    address nft;
    uint tokenId;
    uint price;
    address payable seller;
    uint expiryOn;
    bool sold;
}

// https://ethereum.stackexchange.com/questions/24713/how-can-a-deployed-contract-call-another-deployed-contract-by-interface-and-ad
// describe the interface
interface NFTMarketplaceV2{
    // empty because we're not concerned with internal details
    function getListedItem(uint256 _itemId) external view returns (Item memory);
    function getOwner() external view returns (address);
    function crossMakeItem(address _nft, uint _tokenId, uint _price, uint _expiryOn, address _seller, uint sigExpiry, bytes memory signature) external;
    function crossPurchaseItem(uint _itemId, address _buyer) external;
    function crossDelistItem(uint _itemId, address _seller) external;
    function getTotalPrice(uint _itemId) view external returns (uint);
    function getItemCount() external view returns (uint);
}

// interface OneNFT {
//     function mint(string memory _tokenURI) external returns(uint);
// }

contract MessageReceiver is AxelarExecutable {
    IAxelarGasService immutable gasReceiver;
    //owner is the contract address that created the smart contract
    address owner;
    NFTMarketplaceV2 nftMarket;
    string public sourceChain;

    constructor(address _gateway, address _gasReceiver)
        AxelarExecutable(_gateway)
    {
        gasReceiver = IAxelarGasService(_gasReceiver);
        owner = payable(msg.sender);
    }

    // function compareStrings(string memory a, string memory b) internal pure returns (bool) {
    //     return (keccak256(abi.encodePacked((a))) == keccak256(abi.encodePacked((b))));
    // }

    function getMarketplace() public view returns (address) {
        return address(nftMarket);
    }

    function setMarketplace(address _nftMarket) public {
        require(owner == msg.sender, "Only owner can set marketplace");
        nftMarket = NFTMarketplaceV2(_nftMarket);
    }

    event Executed();
    event Failed(string reason);
    event Transfer(address indexed from, address indexed to, uint256 value);

    function _execute(
        string calldata sourceChain_,
        string calldata,
        bytes calldata payload
    ) internal override {
        sourceChain = sourceChain_;
        (
            address nftOwner,
            address nftAddress,
            uint256 actionCall,
            uint256 listTokenId,
            uint256 listPrice,
            uint256 listExpiry,
            uint256 sigExpiry,
            bytes memory signature
        ) = abi.decode(payload, (address, address, uint256, uint256, uint256, uint256, uint256, bytes));

        // actionCall 2 = mint
        // actionCall 1 = list
        // actionCall 0 = delist
        if (actionCall == 1) {
            // list
            nftMarket.crossMakeItem(nftAddress, listTokenId, listPrice, listExpiry, nftOwner, sigExpiry, signature);
        } else if (actionCall == 0) {
            // delist
            nftMarket.crossDelistItem(listTokenId, nftOwner);
        }
        emit Executed();
    }

    function _executeWithToken(
        string calldata,
        string calldata,
        bytes calldata payload,
        string calldata tokenSymbol,
        uint256 amount
    ) internal override {
        // decode payload
        (
            address recipient,
            uint256 itemId
        ) = abi.decode(payload, (address, uint256));
        address tokenAddress = gateway.tokenAddresses(tokenSymbol);

        // we cannot approve contract like this, axelar txs will stucked and need to manually approve in axelarscan
        // axlToken.approve(address(nftMarket), amount);

        // transfer user balance to nftMarket (custody) - not working as execution and token transfer in same txs
        // user balance haven't get updated / commited into the block
        // therefore when we check user balance in the NftMarket contract, the data up to date
        // axlToken.transfer(address(nftMarket), amount);

        // get seller and owner info from listedInfo
        Item memory targetItem = nftMarket.getListedItem(itemId);
        IERC20 axlToken = IERC20(tokenAddress);
        uint _totalPrice = nftMarket.getTotalPrice(itemId);

        // valid itemCount
        uint itemCount = nftMarket.getItemCount();

        if (amount != _totalPrice) {
            // if sent amount is not tally with nft price, refund deposit to user wallet
            axlToken.transfer(recipient, amount);
            emit Failed("Nft price and payment not tally");

        } else if (targetItem.expiryOn <= block.timestamp || targetItem.sold) {
            // stop purchasing off list nft (refund aUsdc)
            axlToken.transfer(recipient, amount);
            emit Failed("Nft is not on sale");

        } else if (!(itemId > 0 && itemId <= itemCount)) {
            axlToken.transfer(recipient, amount);
            emit Failed("Invalid itemId");

        } else {
            //Transfer the proceeds from the sale to the seller of the NFT
            address marketplaceOwner = nftMarket.getOwner();

            axlToken.transfer(targetItem.seller, targetItem.price);

            //Transfer the listing fee to the marketplace creator
            axlToken.transfer(marketplaceOwner, _totalPrice - targetItem.price);

            // execute transfer nft call
            nftMarket.crossPurchaseItem(itemId, recipient);
        }

        emit Executed();
    }
}
