const { ethers, upgrades } = require('hardhat');

async function main() {
  const [ owner ] = await ethers.getSigners();

  const dusd = '0x8A6fdeF3eE1470653F3133E42370a404E3A330c9';
  const dai = '0x200c2386A02cbA50563b7b64615B43Ab1874a06e';
  const fluid = '0x876Ec6bE52486Eeec06bc06434f3E629D695c6bA';
  const aArbDai = '0x38c4f078813bcAc22b4c580A870F812377615D59';
  const tokenTransferProxy = '0x8A6fdeF3eE1470653F3133E42370a404E3A330c9';
  const augustusAddress = '0x8A6fdeF3eE1470653F3133E42370a404E3A330c9';
  const aavePool = '0x9C55a3C34de5fd46004Fa44a55490108f7cE388F';
  const fluidTreasury = '0x681220A950BC5014459Af295bDe42eB684a31347';
	const balancerVault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
	const balancerPoolId = '0xd89746affa5483627a87e55713ec1905114394950002000000000000000000bf';

  const AaveVaultFactory = await ethers.getContractFactory('AaveVaultUpgradable');
	const proxy = await upgrades.deployProxy(AaveVaultFactory, [dusd, dai, fluid, aArbDai, tokenTransferProxy, augustusAddress, aavePool, fluidTreasury, balancerVault, balancerPoolId]);
  await proxy.deployed();
	console.log(`AaveVaultProxy deployed to: `, proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });