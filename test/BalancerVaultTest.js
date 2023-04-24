const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");

const unlockAccount = async (address) => {
	await hre.network.provider.send("hardhat_impersonateAccount", [address]);
	return hre.ethers.provider.getSigner(address);
};

describe("Balancer Vault", function () {
  let BalancerVaultFactory, MockERC20Factory
  let balancerVaultInstance
  let owner, addr1, addr2, addrs


  const dusd = '0xF0B5cEeFc89684889e5F7e0A7775Bd100FcD3709';
  const dai = '0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1';
  const fluid = '0x876Ec6bE52486Eeec06bc06434f3E629D695c6bA';
  const fluidTreasury = '0xa94Eff15A6FF752e4A8DcA9c7FB42F4ec45992cB';
  const balancerVault = '0xBA12222222228d8Ba445958a75a0704d566BF2C8';
  const balancerHelper = '0x77d46184d22CA6a3726a2F500c776767b6A3d6Ab';
	const balancerPoolId = '0xd89746affa5483627a87e55713ec1905114394950002000000000000000000bf';
  const dusdDaiPool = '0xD89746AFfa5483627a87E55713Ec190511439495';

  let testnetAccount;
  let proxy;

  before(async function() {
    
    //MockERC20Factory = await hre.ethers.getContractFactory("MockERC20")
  })

  beforeEach(async function() {
    const BalancerVaultFactory = await ethers.getContractFactory('BalancerVaultUpgradable');
	  proxy = await upgrades.deployProxy(BalancerVaultFactory, [dusd, dai, fluid, fluidTreasury, balancerVault, balancerHelper, balancerPoolId, dusdDaiPool]);
    await proxy.deployed();
	  console.log(`BalancerVaultProxy deployed to: `, proxy.address);
    
  })

  it.only("deposit DAI", async () => {
    //testnetAccount = await unlockAccount(testnetAccountAddr);
    testnetAccount = await unlockAccount("0x1D693a4425bf7eD10FE7775E2b65b072019FFceb")

    const DAI = await hre.ethers.getContractAt("MockERC20", dai);
    await DAI.connect(testnetAccount).approve(proxy.address, 1);
    let tx = await proxy.connect(testnetAccount).deposit(DAI.address, 1);
    let txr = await tx.wait()
    console.log(txr)

    //await balancerVaultInstance.connect(testnetAccount).withdrawAll(dai);
  });

  it("deposit token A and token B", async () => {
    testnetAccount = await unlockAccount(testnetAccountAddr);

    const tdusdContract = await hre.ethers.getContractAt("MockERC20", tdusd);
    await tdusdContract.connect(testnetAccount).approve(balancerVaultInstance.address, "1000000000000000000");
    await balancerVaultInstance.connect(testnetAccount).deposit(tdusd, "1000000000000000000");

    const daiContract = await hre.ethers.getContractAt("MockERC20", dai);
    await daiContract.connect(testnetAccount).approve(balancerVaultInstance.address, "1000000000000000000");
    await balancerVaultInstance.connect(testnetAccount).deposit(dai, "1000000000000000000");

    await balancerVaultInstance.connect(testnetAccount).withdraw(dai, "1500000000000000000");

    await balancerVaultInstance.connect(testnetAccount).withdraw(tdusd, "150000000000000000");

    await tdusdContract.connect(testnetAccount).approve(balancerVaultInstance.address, "2000000000000000000");
    await balancerVaultInstance.connect(testnetAccount).deposit(tdusd, "2000000000000000000");

    console.log(await balancerVaultInstance.callStatic.userWithdrawalAmount(testnetAccountAddr, dai));
    console.log(await balancerVaultInstance.callStatic.userReward(testnetAccountAddr, dai));
    await balancerVaultInstance.connect(testnetAccount).withdraw(dai, "1500000000000000000");
  });

  it("deposit BPT and withdraw token A", async () => {
    testnetAccount = await unlockAccount(testnetAccountAddr);

    const bptContract = await hre.ethers.getContractAt("MockERC20", tdusdDaiPool);
    await bptContract.connect(testnetAccount).approve(balancerVaultInstance.address, "1000000000000000");

    await balancerVaultInstance.connect(testnetAccount).deposit(tdusdDaiPool, "1000000000000000");
    await balancerVaultInstance.connect(testnetAccount).withdrawAll(dai);
  });
});
