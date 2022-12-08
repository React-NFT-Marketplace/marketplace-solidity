import { Contract, ethers, getDefaultProvider, providers, BigNumber } from "ethers";
import {
  AxelarQueryAPI,
  Environment,
  EvmChain,
  GasToken,
} from "@axelar-network/axelarjs-sdk";

import AxelarGatewayContract from "../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IAxelarGateway.sol/IAxelarGateway.json";
import MessageSenderContract from "../artifacts/contracts/MessageSender.sol/MessageSender.json";
import MessageReceiverContract from "../artifacts/contracts/MessageReceiver.sol/MessageReceiver.json";
import NFTMarketplace from "../artifacts/contracts/NFTMarketplaceV2.sol/NFTMarketplaceV2.json";
import OneNFT from "../artifacts/contracts/OneNFT.sol/OneNFT.json";
import IERC20 from "../artifacts/@axelar-network/axelar-gmp-sdk-solidity/contracts/interfaces/IERC20.sol/IERC20.json";
import { isTestnet, wallet } from "../config/constants";
import { TypedDataDomain } from "@ethersproject/abstract-signer";
import _ from "lodash";

console.log(isTestnet);
let chains = isTestnet
  ? require("../config/testnet.json")
  : require("../config/local.json");

// const moonbeamChain = chains.find(
//   (chain: any) => chain.name === "Moonbeam",
// ) as any;
_.find(chains, (chain:any) => chain.name === "BscTest")
const bscChain = _.find(chains, (chain:any) => chain.name === "BscTest");
const avalancheChain = _.find(chains, (chain:any) => chain.name === "Avalanche");

if (!bscChain || !avalancheChain) process.exit(0);

const useMetamask = false; // typeof window === 'object';

const bscProvider = useMetamask
  ? new providers.Web3Provider((window as any).ethereum)
  : getDefaultProvider(bscChain.rpc);
const bscConnectedWallet = useMetamask
  ? (bscProvider as providers.Web3Provider).getSigner()
  : wallet.connect(bscProvider);
const avalancheProvider = getDefaultProvider(avalancheChain.rpc);
const avalancheConnectedWallet = wallet.connect(avalancheProvider);

const srcGatewayContract = new Contract(
  avalancheChain.gateway,
  AxelarGatewayContract.abi,
  avalancheConnectedWallet,
);

const destGatewayContract = new Contract(
  bscChain.gateway,
  AxelarGatewayContract.abi,
  bscConnectedWallet,
);

const sourceContract = new Contract(
  avalancheChain.messageSender as string,
  MessageSenderContract.abi,
  avalancheConnectedWallet,
);

const destContract = new Contract(
  bscChain.messageReceiver as string,
  MessageReceiverContract.abi,
  bscConnectedWallet,
);

const sourceMarketplace = new Contract(
    avalancheChain.nftMarketplace as string,
    NFTMarketplace.abi,
    avalancheConnectedWallet,
);

const destMarketplace = new Contract(
    bscChain.nftMarketplace as string,
    NFTMarketplace.abi,
    bscConnectedWallet,
);

const sourceNFT = new Contract(
    avalancheChain.oneNFT as string,
    OneNFT.abi,
    avalancheConnectedWallet,
);

const destNFT = new Contract(
    bscChain.oneNFT as string,
    OneNFT.abi,
    bscConnectedWallet,
);

export function generateRecipientAddress(): string {
  return ethers.Wallet.createRandom().address;
}

export async function mintTokenToSourceChain(
    onSent: (txhash: string) => void,
  ) {
    console.log(`trying to mint`);
    const receipt = await sourceNFT
      .mint(
        "https://api.npoint.io/efaecf7cee7cfe142516",
      )
      .then((tx: any) => tx.wait());
    console.log(receipt);
    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

  export async function mintTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE,
      GasToken.AVAX,
      1000000,
      2
    );

    const receipt = await sourceContract
      .crossChainMint(
        "Binance",
        destContract.address,
        destNFT.address,
        "https://api.npoint.io/efaecf7cee7cfe142516",
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

  export async function delistTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE as EvmChain,
      GasToken.AVAX,
      1000000,
      2
    );

    const receipt = await sourceContract
      .crossChainDelist(
        "Binance",
        destContract.address,
        1,
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

  export async function listTokenToDestChain(
    onSent: (txhash: string) => void,
  ) {

    const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

    // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
    const gasFee = await api.estimateGasFee(
      EvmChain.AVALANCHE,
      EvmChain.BINANCE,
      GasToken.AVAX,
      1000000,
      2
    );

    const tokenId = 3;
    // set deadline in 14 days
    const deadline = Math.round(Date.now() / 1000 + (14 * 24 * 60 * 60));
    const ownerAddress = await bscConnectedWallet.getAddress();

    const contractName = await destNFT.name();
    const nftNonce = await destNFT.nonces(tokenId);
    const signature = await sign(contractName, bscChain.oneNFT, bscChain.nftMarketplace, tokenId, bscChain.chainId, nftNonce, deadline, bscConnectedWallet);

    // listing timeclear
    let currentTime = new Date();
    currentTime.setDate(currentTime.getDate()+14);
    const newTime = Math.round(currentTime.getTime() / 1000);

    console.log(`spender: ${bscChain.messageReceiver}`);
    // console.log(`signature: ${signature}`);
    console.log(`deadline: ${deadline}`);

    const receipt = await sourceContract
      .crossChainList(
        "Binance",
        destContract.address,
        destNFT.address,
        tokenId,
        ethers.utils.parseUnits('0.1', 6),
        newTime,
        deadline,
        signature,
        {
          value: BigInt(isTestnet ? gasFee : 3000000)
        },
      )
      .then((tx: any) => tx.wait());

    console.log({
      txHash: receipt.transactionHash,
    });
    onSent(receipt.transactionHash);

    // Wait destination contract to execute the transaction.
    return new Promise((resolve, reject) => {
      destContract.on("Executed", () => {
        destContract.removeAllListeners("Executed");
        resolve(null);
      });
    });
  }

export async function sendTokenToDestChain(
  itemId: number,
  onSent: (txhash: string) => void,
) {
  // Get token address from the gateway contract
  const tokenAddress = await srcGatewayContract.tokenAddresses("aUSDC");

  const erc20 = new Contract(
    tokenAddress,
    IERC20.abi,
    avalancheConnectedWallet,
  );

  console.log(`itemId: ${itemId}`);
  // Approve the token for the amount to be sent
  const amount = await destMarketplace.getTotalPrice(itemId);

//   console.log(amount);
//   console.log(ethers.BigNumber.from('105000'));

  await erc20
    // .approve(sourceContract.address, ethers.utils.parseUnits(amount, 6))
    .approve(sourceContract.address, amount)
    .then((tx: any) => tx.wait());

  const api = new AxelarQueryAPI({ environment: Environment.TESTNET });

  // Calculate how much gas to pay to Axelar to execute the transaction at the destination chain
  const gasFee = await api.estimateGasFee(
    EvmChain.AVALANCHE,
    EvmChain.BINANCE,
    GasToken.AVAX,
    1000000,
    2
  );

  const receipt = await sourceContract
    .crossChainBuy(
      "Binance",
      destContract.address,
      "aUSDC",
      amount,
      1,
      {
        value: BigInt(isTestnet ? gasFee : 3000000)
      },
    )
    .then((tx: any) => tx.wait());

  console.log({
    txHash: receipt.transactionHash,
  });
  onSent(receipt.transactionHash);

  // Wait destination contract to execute the transaction.
  return new Promise((resolve, reject) => {
    destContract.on("Executed", () => {
      destContract.removeAllListeners("Executed");
      resolve(null);
    });
  });
}

export function truncatedAddress(address: string): string {
  return (
    address.substring(0, 6) + "..." + address.substring(address.length - 4)
  );
}

export async function getBalance(addresses: string[], isSource: boolean) {
  const contract = isSource ? srcGatewayContract : destGatewayContract;
  const connectedWallet = isSource
    ? avalancheConnectedWallet
    : bscConnectedWallet;
  const tokenAddress = await contract.tokenAddresses("aUSDC");
  const erc20 = new Contract(tokenAddress, IERC20.abi, connectedWallet);
  const balances = await Promise.all(
    addresses.map(async (address) => {
      const balance = await erc20.balanceOf(address);
      return ethers.utils.formatUnits(balance, 6);
    }),
  );
  return balances;
}


// helper to sign using (spender, tokenId, nonce, deadline) EIP 712
async function sign(
    contractName,
    verifyingContract,
    spender,
    tokenId,
    chainId,
    nonce,
    deadline,
    connectedWallet
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
      typedData.domain,
      { Permit: typedData.types.Permit },
      typedData.message
    );

    return signature;
}