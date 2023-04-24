const { ethers } = require('hardhat');

async function main() {
  const [ owner ] = await ethers.getSigners();
  
  const vault = '0xAbc1544166e9194DFC4533275853fcA971Aba390';
  const dusdDaiPool = '0xD89746AFfa5483627a87E55713Ec190511439495';
  const dusd = '0xF0B5cEeFc89684889e5F7e0A7775Bd100FcD3709';
  const dai = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';

  const vaultContract = await ethers.getContractAt("BalancerVaultUpgradable", vault);

  const dusdContract = await ethers.getContractAt("MockERC20", dusd);
  console.log(await vaultContract.callStatic.userReward('0x5718DDC55dD3412e9E706626e513EEe8f6C53828', dusd));
  console.log(await vaultContract.callStatic.userReward('0x5718DDC55dD3412e9E706626e513EEe8f6C53828', dai));
  // console.log(await vaultContract.callStatic.getTokenAmountFromBPT(dusd, "3049771119742784647"));
  // await dusdContract.approve(vault, "100000");
  // await vaultContract.deposit(dusd, "100000");

  // const bptContract = await ethers.getContractAt("MockERC20", dusdDaiPool);
  // await bptContract.approve(vault, "100000000000000000");

  // const daiContract = await ethers.getContractAt("MockERC20", dai);
  // await daiContract.approve(vault, "1000000000000000000");
  // await vaultContract.deposit(dai, "1000000000000000000");

  // await vaultContract.withdraw(dai, "100000000000000000");
  // await vaultContract.withdrawAll(dai);
}

main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });