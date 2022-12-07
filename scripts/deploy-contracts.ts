import fs from "fs/promises";
import {getDefaultProvider} from "ethers";
import {isTestnet, wallet} from "../config/constants";
import {ethers} from "ethers";
import _ from "lodash";

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
// const chainName = ["Moonbeam", "Avalanche", "BscTest", "Mumbai", "Fantom"];
const chainName = ["BscTest", "Avalanche"];

const nftName = [
    {name: "bscNFT", symbol: "bNFT"},
    {name: "avaxNFT", symbol: "aNFT"}
];

const tokenUrl = [
    "https://api.onenft.shop/metadata/c8fc85bd753c79f3ba0b8e9028c6fb66",
    "https://api.onenft.shop/metadata/a3e8cd74020705eef14d1920f591348d",
    "https://api.onenft.shop/metadata/037e7c3068fd135337829a585ebde17c",
    "https://api.onenft.shop/metadata/696e7b1aa0fa2369077a9dcefdf1fc08",
    "https://api.onenft.shop/metadata/80029f46fef3ed6d3c6e036d3ce570d8"
];
const chainInfo: any = [];

async function deploy(chain: any, tokenUrl: string, nftName: any) {
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

    console.log(`oneNFTContract deployed on ${
        chain.name
    }:`, oneNFT.address,);
    chain.oneNFT = oneNFT.address;

    // create token 1
    await(await oneNFT.mint(tokenUrl)).wait(1);
    // create token 2
    await(await oneNFT.mint(tokenUrl)).wait(1);

    let currentTime = new Date();
    currentTime.setDate(currentTime.getDate()+14);
    const newTime = Math.round(currentTime.getTime() / 1000);

    await(await oneNFT.approve(marketplace.address, 1)).wait(1);

    await(await marketplace.makeItem(oneNFT.address, 1, ethers.utils.parseUnits('0.1', 6), newTime)).wait(1);
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
        promises.push(deploy(chainInfo[cn], tokenUrl[cnIndex], nftName[cnIndex]));
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

main();
