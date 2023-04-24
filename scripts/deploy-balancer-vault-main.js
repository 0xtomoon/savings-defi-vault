const { ethers, upgrades } = require('hardhat');

async function main() {
  const [ owner ] = await ethers.getSigners();

  const dusd = '0xF0B5cEeFc89684889e5F7e0A7775Bd100FcD3709';
  const dai = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';
  const fluid = '0x876Ec6bE52486Eeec06bc06434f3E629D695c6bA';
  const fluidTreasury = '0xd1Db73B1288AECf93743CBb459c0385BDD125839';
  const balancerVault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
  const balancerHelper = '0x77d46184d22CA6a3726a2F500c776767b6A3d6Ab';
	const balancerPoolId = '0xd89746affa5483627a87e55713ec1905114394950002000000000000000000bf';
  const dusdDaiPool = '0xD89746AFfa5483627a87E55713Ec190511439495';

  const BalancerVaultFactory = await ethers.getContractFactory('BalancerVaultUpgradable');
	//const proxy = await upgrades.deployProxy(BalancerVaultFactory, [dusd, dai, fluid, fluidTreasury, balancerVault, balancerHelper, balancerPoolId, dusdDaiPool]);
  //await proxy.deployed();
	//console.log(`BalancerVaultProxy deployed to: `, proxy.address);
  await upgrades.upgradeProxy("0x4577A292ceE8f3B32853A1E16a425EcA2aF388dd", BalancerVaultFactory);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
