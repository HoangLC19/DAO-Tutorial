const { ethers } = require("hardhat");
const { CRYPTODEVS_NFT_CONTRACT_ADDRESS } = require("../constants");

//* How to change this file
/*
- Fill in the `ContractName` with your contract name.
- Uncomment the verification process if you want to verify your contract but make sure to uncomment the same in the `hardhat.config.js` and change the values as required.

You can pass in values into your contract like doing the following :
ex : Asssume you have a string and a number to pass
` const lock = await Lock.deploy("hello", 5);`
*/

//* Sample Deployment
/*
  const Lock = await hre.ethers.getContractFactory("ContractName");
  const lock = await Lock.deploy();

  await lock.deployed();

  console.log("Contract Deployed to : ", lock.address);

  console.log("Sleeping...");
  await sleep(50000);
  await hre.run("verify:verify", {
    address: lock.address,
    constructorArguments: [],
  });
*/

async function main() {
  // Write your deployment files here
  
  // Deploy the FakeNFTMarketplace first
  const FakeNFTMarketplace = await ethers.getContractFactory("FakeNFTMarketplace");
  const fakeNFTMarketplace = await FakeNFTMarketplace.deploy();
  await fakeNFTMarketplace.deployed();
  console.log("FakeNFTMarketplace Deployed to : ", fakeNFTMarketplace.address);
  //0xe275aEbc264Ba51BC727e4cB74eE73Ce7BCe0CEB

  // Deploy the CryptodevDao contraxt
  const CryptoDevsDAO = await ethers.getContractFactory("CryptoDevsDAO");
  const cryptoDevsDAO = await CryptoDevsDAO.deploy(fakeNFTMarketplace.address, CRYPTODEVS_NFT_CONTRACT_ADDRESS, { value: ethers.utils.parseEther("1") });
  await cryptoDevsDAO.deployed();
  console.log("CryptoDevsDAO deployed to: ", cryptoDevsDAO.address);
  //0x8890CC23904da3Bf37629E8CA64CeB068f9F2eC4
}

// Async Sleep function
function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
