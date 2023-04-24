const { ethers, upgrades } = require('hardhat');


async function deploy(){
  const [ owner ] = await ethers.getSigners();

  const dusd = '0xF0B5cEeFc89684889e5F7e0A7775Bd100FcD3709';
  const dai = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';
  const fluid = '0x876Ec6bE52486Eeec06bc06434f3E629D695c6bA';
  const aArbDai = '0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE';
  const tokenTransferProxy = '0x216B4B4Ba9F3e719726886d34a177484278Bfcae';
  const augustusAddress = '0xDEF171Fe48CF0115B1d80b88dc8eAB59176FEe57';
  const aavePool = '0x794a61358D6845594F94dc1DB02A252b5b4814aD';
  const fluidTreasury = '0xa94Eff15A6FF752e4A8DcA9c7FB42F4ec45992cB';
	const balancerVault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
	const balancerPoolId = '0xd89746affa5483627a87e55713ec1905114394950002000000000000000000bf';

  const AaveVaultFactory = await ethers.getContractFactory('AaveVaultUpgradable');
	const proxy = await upgrades.deployProxy(AaveVaultFactory, [dusd, dai, fluid, aArbDai, tokenTransferProxy, augustusAddress, aavePool, fluidTreasury, balancerVault, balancerPoolId]);
  await proxy.deployed();
	console.log(`AaveVaultProxy deployed to: `, proxy.address);
}

async function update(){
  const [ owner ] = await ethers.getSigners();
  const proxyAddress = "0x93f672915770a37d7fd545845c9c04803e6a92a5"

  const AaveVaultFactory = await ethers.getContractFactory('AaveVaultUpgradable');
	const proxy = await upgrades.upgradeProxy(proxyAddress,AaveVaultFactory);
  console.log(`AaveVaultProxy deployed to: `, proxy.address);
}
async function main() {
  await update();
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
