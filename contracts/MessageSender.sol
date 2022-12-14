//SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IERC20} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol";
import {IAxelarGateway} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol";
import {IAxelarGasService} from "@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGasService.sol";

contract MessageSender {
    IAxelarGasService immutable gasReceiver;
    IAxelarGateway immutable gateway;

    // struct OrderInfo {
    //     uint256 tokenId;
    //     string symbol;
    //     uint256 amount;
    // }

    constructor(address _gateway, address _gasReceiver) {
        gateway = IAxelarGateway(_gateway);
        gasReceiver = IAxelarGasService(_gasReceiver);
    }

    function crossChainMint(
        string calldata destinationChain,
        string calldata destinationAddress,
        address nftAddress,
        string calldata tokenURI
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // delist action = 0
        // address nftOwner, address nftAddress, uint256 actionCall, uint256 listTokenId, uint256 listPrice, uint256 listExpiry, uint256 sigExpiry, bytes memory signature, string memory tokenURI
        bytes memory payload = abi.encode(msg.sender, nftAddress, 2, 0, 0, 0, 0, "", tokenURI);

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }


    function crossChainDelist(
        string calldata destinationChain,
        string calldata destinationAddress,
        uint256 tokenId
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // delist action = 0
        // address nftOwner, address nftAddress, uint256 actionCall, uint256 listTokenId, uint256 listPrice, uint256 listExpiry, uint256 sigExpiry, bytes memory signature, string memory tokenURI
        bytes memory payload = abi.encode(msg.sender, address(0x0), 0, tokenId, 0, 0, 0, "", "");

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function crossChainList(
        string calldata destinationChain,
        string calldata destinationAddress,
        address nftAddress,
        uint256 tokenId,
        uint256 amount,
        uint256 listExpiry,
        uint256 sigExpiry,
        bytes calldata signature
    ) external payable {
        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case

        // list action = 1
        // address nftOwner, address nftAddress, uint256 actionCall, uint256 listTokenId, uint256 listPrice, uint256 listExpiry, uint256 sigExpiry, bytes memory signature, string memory tokenURI
        bytes memory payload = abi.encode(msg.sender, nftAddress, 1, tokenId, amount, listExpiry, sigExpiry, signature, "");

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCall{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                msg.sender
            );
        }

        gateway.callContract(
            destinationChain,
            destinationAddress,
            payload
        );
    }

    function crossChainBuy(
        string calldata destinationChain,
        string calldata destinationAddress,
        string calldata symbol,
        uint256 amount,
        uint256 itemId
    ) external payable {
        address tokenAddress = gateway.tokenAddresses(symbol);
        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenAddress).approve(address(gateway), amount);

        // make sure gateway and gasReceiver payload is the same
        // axelar will not allow diff payload content as it consume diff gas amount
        // axelar rugi in this case
        bytes memory payload = abi.encode(msg.sender, itemId);

        if (msg.value > 0) {
            gasReceiver.payNativeGasForContractCallWithToken{value: msg.value}(
                address(this),
                destinationChain,
                destinationAddress,
                payload,
                symbol,
                amount,
                msg.sender
            );
        }

        gateway.callContractWithToken(
            destinationChain,
            destinationAddress,
            payload,
            symbol,
            amount
        );
    }
}
