const { ethers, upgrades } = require('hardhat');

async function main() {
  const [ owner ] = await ethers.getSigners();

  const tdusd = '0xfD7B02F17a75A8BC0acC790a3b2270182f4c3c87';
  const dai = '0x8c9e6c40d3402480ACE624730524fACC5482798c';
  const fluid = '0x876Ec6bE52486Eeec06bc06434f3E629D695c6bA';
  const fluidTreasury = '0xa94Eff15A6FF752e4A8DcA9c7FB42F4ec45992cB';
  const balancerVault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
  const balancerHelper = '0x5aDDCCa35b7A0D07C74063c48700C8590E87864E';
	const balancerPoolId = '0x748ffbb0702276952d399e786296274386002da8000200000000000000000254'; // BAL-WETH goerli pool
  const tdusdDaiPool = '0x748FfBB0702276952D399e786296274386002da8';

  const BalancerVaultFactory = await ethers.getContractFactory('BalancerVaultUpgradable');
  // const balancer = await BalancerVaultFactory.deploy();
  // await balancer.deployed();
  // console.log(`Impl: `, balancer.address);
	// const proxy = await upgrades.deployProxy(BalancerVaultFactory, [tdusd, dai, tdusd, fluidTreasury, balancerVault, balancerHelper, balancerPoolId, tdusdDaiPool]);
  await upgrades.upgradeProxy("0x65F7a978486c7EBB2133a8E3B4f28F15E7F3b01c", BalancerVaultFactory);
  // await proxy.deployed();
  
	// console.log(`BalancerVaultProxy deployed to: `, proxy.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
