import fs from "fs/promises";
import {getDefaultProvider, BigNumber} from "ethers";
import {isTestnet, wallet} from "../config/constants";
import {ethers} from "ethers";
import _ from "lodash";
import { TRANSFER_RESULT } from "@axelar-network/axelarjs-sdk";

const {utils: {
        deployContract
    }} = require("@axelar-network/axelar-local-dev");

// load contracts
const MessageSenderContract = require("../artifacts/contracts/MessageSender.sol/MessageSender.json");
const MessageReceiverContract = require("../artifacts/contracts/MessageReceiver.sol/MessageReceiver.json");
const MarketplaceContract = require("../artifacts/contracts/NFTMarketplaceV2.sol/NFTMarketplaceV2.json");
const OneNFTContract = require("../artifacts/contracts/OneNft.sol/OneNFT.json");

let chains = isTestnet ? require("../config/testnet.json") : require("../config/local.json");

// get chains
const chainName = ["Moonbeam", "Avalanche", "BscTest", "Mumbai", "Fantom"];

const nftName = [
    {name: "moonNFT", symbol: "mNFT"},
    {name: "avaxNFT", symbol: "aNFT"},
    {name: "bscNFT", symbol: "bNFT"},
    {name: "polyNFT", symbol: "pNFT"},
    {name: "ftmNFT", symbol: "fNFT"},
];

const tokenUrl: any = {
    "Moonbeam": [
        "https://ipfs.moralis.io:2053/ipfs/QmPzp6gumsAwfY6tBJ2B4UEmXKXyV4wzUHw9vgiP6NSMb5/metadata/Moonbeam/blackwidow-penguin",
        "https://ipfs.moralis.io:2053/ipfs/QmWTYrb6g5Er3ouBTFpBFx8cDfgpWx6B4abbGH7iaDydeK/metadata/Moonbeam/dante-penguin",
        "https://ipfs.moralis.io:2053/ipfs/QmbSJphwDkPJxDHDfua4txiChmoAy4Tnbr9scqKxDMdehQ/metadata/Moonbeam/hawkeye-penguin",
        "https://ipfs.moralis.io:2053/ipfs/QmQYSsGzinKM5oCwfwHki6bEcoZevSPKCZzdqwrCWnz4M1/metadata/Moonbeam/nickfury-penguin",
    ],
    "Avalanche": [
        "https://ipfs.moralis.io:2053/ipfs/QmWsyydkQZY4dSXWKvXNVB75ZndEGAi4H82u9dzuAnb2PS/metadata/Avalanche/doctor-crab",
        "https://ipfs.moralis.io:2053/ipfs/QmPCbiwQTbztZWohozWfRizFkREpBXL5rx8WuNiaoCAt85/metadata/Avalanche/musculine-crab",
        "https://ipfs.moralis.io:2053/ipfs/QmXsXbhKZBXQrVoMwNWGxPtipPVhYyJTZjDqf35TFLHJDh/metadata/Avalanche/venom-crab",
    ],
    "BscTest": [
        "https://ipfs.moralis.io:2053/ipfs/QmVAvweaXekLyfLYuXs5rSsEsTcx8gHt5wCKwnov9ZQq21/metadata/BscTest/ancient-doge",
        "https://ipfs.moralis.io:2053/ipfs/QmcVDYD7Zu8vmAPKwJM6toxU4KAzEHypsok7dQXs1PRPa3/metadata/BscTest/artistic-doge"
    ],
    "Mumbai": [
        "https://ipfs.moralis.io:2053/ipfs/QmXiUPZkZ2yDU5nsAGE9iq4o454ZRjeZiagV6k4g8pXMAC/metadata/Mumbai/bee-panda",
        "https://ipfs.moralis.io:2053/ipfs/QmX84adhvyhhrsfqDJUiR1693dT2WbJSUjjdw4qED6imz8/metadata/Mumbai/plane-panda",
        "https://ipfs.moralis.io:2053/ipfs/QmXGgQHVTSm4kBdpTiv27ZxGNtCg1CwxgcaFisT7F9t42M/metadata/Mumbai/wing-pand",
    ],
    "Fantom": [
        "https://ipfs.moralis.io:2053/ipfs/QmRFysEki6mJCexJrrCSjURTBXJhgG1y6jdKKXzvuKw7iB/metadata/Fantom/iron-lion",
        "https://ipfs.moralis.io:2053/ipfs/QmVsarvpvVyN57E5CR8PU5WRYYQHc2D414jxcDW4XBJv8X/metadata/Fantom/stone-lion",
    ],
};

// const chainName = ["BscTest", "Avalanche"];
// const nftName = [
//     {name: "bscNFT", symbol: "bNFT"},
//     {name: "avaxNFT", symbol: "aNFT"},
// ];
// const tokenUrl = [
//     "https://api.onenft.shop/metadata/c8fc85bd753c79f3ba0b8e9028c6fb66",
//     "https://api.onenft.shop/metadata/a3e8cd74020705eef14d1920f591348d",
// ];

const chainInfo: any = [];

async function deploy(chain: any, metadataUrl: string[], nftName: any) {
    const provider = getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);

    const sender = await deployContract(connectedWallet, MessageSenderContract, [
        chain.gateway, chain.gasReceiver
    ],);
    console.log(`MessageSender deployed on ${
        chain.name
    }:`, sender.address);
    chain.messageSender = sender.address;

    const receiver = await deployContract(connectedWallet, MessageReceiverContract, [
        chain.gateway, chain.gasReceiver
    ],);
    console.log(`MessageReceiver deployed on ${
        chain.name
    }:`, receiver.address);
    chain.messageReceiver = receiver.address;

    const marketplace = await deployContract(connectedWallet, MarketplaceContract, [
        5, receiver.address, chain.crossChainToken
    ],);
    console.log(`MarketplaceContract deployed on ${
        chain.name
    }:`, marketplace.address);
    chain.nftMarketplace = marketplace.address;

    const oneNFT = await deployContract(connectedWallet, OneNFTContract, [
        nftName.name, nftName.symbol
    ],);

    console.log(`OneNFTContract deployed on ${
        chain.name
    }:`, oneNFT.address);
    chain.oneNFT = oneNFT.address;

    // create token 1
    let nftCount = 0;
    for (let tUrl in metadataUrl) {
        console.log(metadataUrl[tUrl]);
        await(await oneNFT.mint(tUrl)).wait(1);
        nftCount++;
    }

    console.log(`Minted ${nftCount} nfts on ${chain.name}`);

    let currentTime = new Date();
    currentTime.setDate(currentTime.getDate()+14);
    const newTime = Math.round(currentTime.getTime() / 1000);

    // await(await oneNFT.approve(marketplace.address, 1)).wait(1);
    // console.log(`Approved nft#1 on ${chain.name}`);

    const nftId = 1;
    const contractName = await oneNFT.name();
    const nftNonce = await oneNFT.nonces(nftId);
    // set deadline in 1 days
    const sigExpiry = Math.round(Date.now() / 1000 + (7 * 24 * 60 * 60));

    const signature = await sign(contractName, oneNFT.address, marketplace.address, nftId, chain.chainId, nftNonce, sigExpiry, connectedWallet);

    await(await marketplace.makeItem(oneNFT.address, nftId, ethers.utils.parseUnits('0.1', 6), newTime, sigExpiry, signature)).wait(1);

    console.log(`Listed nft in ${
        chain.name
    }`);

    // set nftMarketplace on MessageReceiver
    await(await receiver.setMarketplace(marketplace.address)).wait(1);
    console.log(`Set marketplace [${
        marketplace.address
    }] to ${
        chain.name
    } receiver`);

    return chain;
}

// deploy script
async function main() {
    let cnIndex = 0;
    const promises = [];
    for (let cn in chainName) {
        const cName = chainName[cn];
        chainInfo[cn] = chains.find((chain : any) => chain.name === cName);
        console.log(`Deploying [${cName}]`);
        // chainInfo[cn] = await deploy(chainInfo[cn], tokenUrl[cnIndex]);
        promises.push(deploy(chainInfo[cn], tokenUrl[cName], nftName[cnIndex]));
        cnIndex += 1;
    }
    const result = await Promise.all(promises);

    // update chains
    // chainInfo = _.values(chainInfo);
    if (isTestnet) {
        await fs.writeFile("config/testnet.json", JSON.stringify(result, null, 2),);
    } else {
        await fs.writeFile("config/local.json", JSON.stringify(result, null, 2),);
    }
}

// helper to sign using (spender, tokenId, nonce, deadline) EIP 712
async function sign(
    contractName: String,
    verifyingContract: String,
    spender: String,
    tokenId: number,
    chainId: number,
    nonce: BigNumber,
    deadline: number,
    connectedWallet: any
  ) {

    const typedData = {
      types: {
        Permit: [
          { name: "spender", type: "address" },
          { name: "tokenId", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      },
      primaryType: "Permit",
      domain: {
        name: contractName,
        version: "1",
        chainId: chainId,
        verifyingContract: verifyingContract,
      },
      message: {
        spender,
        tokenId,
        nonce,
        deadline
      },
    };

    // sign Permit
    // assume deployer is the owner
    const deployer = connectedWallet;

    const signature = await deployer._signTypedData(
      typedData.domain as any,
      { Permit: typedData.types.Permit },
      typedData.message
    );

    return signature;
  }

main();
