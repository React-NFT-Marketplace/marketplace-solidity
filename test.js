require("dotenv").config();
const ethers = require('ethers');
const wallet = new ethers.Wallet(process.env.NEXT_PUBLIC_EVM_PRIVATE_KEY);
const MarketplaceContract = require("./artifacts/contracts/NFTMarketplaceV2.sol/NFTMarketplaceV2.json");
const OneNFTContract = require("./artifacts/contracts/OneNft.sol/OneNFT.json");

const chain =   {
    "name": "BscTest",
    "chainId": 97,
    "gateway": "0x4D147dCb984e6affEEC47e44293DA442580A3Ec0",
    "rpc": "https://data-seed-prebsc-1-s3.binance.org:8545",
    "gasReceiver": "0xbE406F0189A0B4cf3A05C286473D23791Dd44Cc6",
    "tokenName": "BNB",
    "tokenSymbol": "BNB",
    "executableSample": "0x9372350Abb3B5c10DB1BB858e0bCf91eFa74d946",
    "constAddressDeployer": "0x98b2920d53612483f91f12ed7754e51b4a77919e",
    "crossChainToken": "0xc2fA98faB811B785b81c64Ac875b31CC9E40F9D2",
    "tokens": {
      "aUSDC": "aUSDC"
    },
    "messageSender": "0xD31F23025d9349bDF5b3b1D354ec934334a58f65",
    "messageReceiver": "0xbf8F911C287E70784c1A80D3bFa047D1036D4d3f",
    "nftMarketplace": "0xcFa0c704F650d696A18ED404f24e236ad4B8eE9b",
    "oneNFT": "0x0bD341f2783e3D2fDfaf9C46D45f0de57FEAeF39"
};

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

(async() => {
    const provider = ethers.getDefaultProvider(chain.rpc);
    const connectedWallet = wallet.connect(provider);
    const walletAddress = await connectedWallet.getAddress();

    const marketplace = new ethers.Contract(
        '0x93c61C1E7b843adc3D37D5c186516464095E0a01',
        MarketplaceContract.abi,
        connectedWallet
    );

    const oneNFT = new ethers.Contract(
        '0xBaa341f8FB00A660799A6B77aC8D778e6846A4fb',
        OneNFTContract.abi,
        connectedWallet
    );

    const nftId = 1;
    // const contractName = 'NFTMarketplaceV2';
    const contractName = await oneNFT.name();

    const nftNonce = await oneNFT.nonces(nftId);
    console.log(`nftNonce: ${nftNonce.toString()}`);

    // set deadline in 1 days
    const sigExpiry = Math.round(Date.now() / 1000 + (7 * 24 * 60 * 60));

    const signature = await sign(contractName, oneNFT.address, marketplace.address, nftId, chain.chainId, nftNonce, sigExpiry, connectedWallet);

    console.log(`sigExpiry: ${sigExpiry}`);
    console.log(`signature: ${signature}`);

    // listing timeclear
    let currentTime = new Date();
    currentTime.setDate(currentTime.getDate()+14);
    const newTime = Math.round(currentTime.getTime() / 1000);

    const tx = await(await marketplace.makeItem(oneNFT.address, nftId, ethers.utils.parseUnits('0.1', 6), newTime, sigExpiry, signature)).wait(1);

    console.log(tx);
})();