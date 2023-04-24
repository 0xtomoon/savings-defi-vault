const { ethers } = require('hardhat');

async function main() {
  const [ owner ] = await ethers.getSigners();
  
  const vault = '0x65F7a978486c7EBB2133a8E3B4f28F15E7F3b01c';
  const tdusdDaiPool = '0x748FfBB0702276952D399e786296274386002da8';
  const tdusd = '0xfD7B02F17a75A8BC0acC790a3b2270182f4c3c87';
  const dai = '0x8c9e6c40d3402480ACE624730524fACC5482798c';

  // const vaultContract = await ethers.getContractAt("BalancerVaultUpgradable", vault);

  // const tdusdContract = await ethers.getContractAt("MockERC20", tdusd);
  // await tdusdContract.approve(vault, "1000000000000000000");
  // await vaultContract.deposit(tdusd, "1000000000000000000");

  // const bptContract = await ethers.getContractAt("MockERC20", tdusdDaiPool);
  // await bptContract.approve(vault, "100000000000000000");

  // const daiContract = await ethers.getContractAt("MockERC20", dai);
  // await daiContract.approve(vault, "1000000000000000000");
  // await vaultContract.deposit(dai, "1000000000000000000");

  // await vaultContract.withdraw(dai, "1000000000000000000");
  // await vaultContract.withdrawAll(tdusd);

  
  // const TestDUSDFactory = await ethers.getContractFactory('MockERC20');
  // const testDUSDInstance = await TestDUSDFactory.deploy("WETH", "WETH"); 
  // await testDUSDInstance.deployed();
  // console.log("WETH: ", testDUSDInstance.address);

  const AggregatorFactory = await ethers.getContractFactory('MockAggregator');
  const aggregatorInstance = await AggregatorFactory.deploy("100000000");
  await aggregatorInstance.deployed();
  console.log("MockAggregator: ", aggregatorInstance.address);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });