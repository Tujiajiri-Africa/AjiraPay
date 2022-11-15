// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const pancakeswapTestnetRouter = '0xD99D1c33F9fC3444f8101754aBC46c52416550D1';
  const pancakeswapMainnetRouter = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
  const ajiraPayTreasury = '0x69949ac6ec279D1eA6176c55393EaEA43dEf8Dec';
  const ajiraPayMainnetTreasury = '0xb00375686741591FeB3541e1740E75FE21CD9f31'
  const ajiraPayPresaleDurationInDays = 35;
  const ajiraPayFinalMainnetAddress = '0xC55b03dC07EC7Bb8B891100E927E982540f0d181'

  //Airdrop Distributor Contract
  const AjiraPayAirdropDristributor = await hre.ethers.getContractFactory('AjiraPayAirdropDistributor');
  //Presale Contract
  const AjiraPayPresaleContract = await hre.ethers.getContractFactory('AjiraPayFinancePrivateSale');
  //Ajira Pay Finace Token Contract
  const AjiraPayFinanceToken = await hre.ethers.getContractFactory('AjiraPayFinanceToken');

  const minRewarCap = 1;
  const maxRewardCap = 1000;
  const tokenDecimals = 18;

  const ajiraPayFinanceToken = await AjiraPayFinanceToken.deploy(pancakeswapMainnetRouter, ajiraPayMainnetTreasury);

  await ajiraPayFinanceToken.deployed();
  
  console.log("Ajira Pay Finance Token deployed to:", ajiraPayFinanceToken.address);

  const ajiraPayPresaleContract = await AjiraPayPresaleContract.deploy(ajiraPayFinalMainnetAddress, ajiraPayMainnetTreasury,ajiraPayPresaleDurationInDays);

  await ajiraPayPresaleContract.deployed();

  console.log("Ajira Pay Finance Presale Contract deployed to:", ajiraPayPresaleContract.address);

  const ajiraPayAirdropDristributor = await AjiraPayAirdropDristributor.deploy(ajiraPayFinalMainnetAddress,ajiraPayMainnetTreasury,minRewarCap,maxRewardCap,tokenDecimals);

  await ajiraPayAirdropDristributor.deployed();

  console.log("Ajira Pay Airdrop Distributor deployed to:", ajiraPayAirdropDristributor.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
