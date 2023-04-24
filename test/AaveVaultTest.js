const { expect } = require("chai");
const { ethers } = require("hardhat");
const hre = require("hardhat");
const { upgrades } = require('hardhat');
const axios = require('axios');

const unlockAccount = async (address) => {
	await hre.network.provider.send("hardhat_impersonateAccount", [address]);
	return hre.ethers.provider.getSigner(address);
};
async function getParaswapCallData({srcToken,srcDecimals,srcAmount},userAddress){
    let destToken = "0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE"
    let destDecimals = 18
    var res = await axios.get(`https://apiv5.paraswap.io/prices/?srcToken=${srcToken}&destToken=${destToken}&amount=${srcAmount}&srcDecimals=${srcDecimals}&destDecimals=${destDecimals}&side=SELL&network=42161&partner=paraswap.io`)  
    let priceData = res.data
    let payload = {}
    payload["srcToken"] = priceData["priceRoute"]["srcToken"]
    payload["destToken"] = priceData["priceRoute"]["destToken"]
    payload["userAddress"] = userAddress
    payload["priceRoute"] = priceData["priceRoute"]
    payload["srcAmount"] = srcAmount
    payload["destAmount"] = priceData["priceRoute"]["destAmount"]
    var res = await axios.post("https://apiv5.paraswap.io/transactions/42161/?ignoreChecks=true", payload)
    return res.data.data
}
describe.only("Aave Vault", function () {
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



    let proxy;
    let userAccount;
    let parawswap_DAI_src = {srcDecimals: 18, srcToken: dai, srcAmount: 10000000000000000000}
    let parawswap_DUSD_src = {srcDecimals: 6, srcToken: dusd, srcAmount: 10000000}
    before(async function() {
        //AaveVault = await hre.ethers.getContractFactory("AaveVaultUpgradable")
        const AaveVaultFactory = await ethers.getContractFactory('AaveVaultUpgradable');
        proxy = await upgrades.deployProxy(AaveVaultFactory, [
            dusd, 
            dai, 
            fluid, 
            aArbDai, 
            tokenTransferProxy, 
            augustusAddress, 
            aavePool, 
            fluidTreasury, 
            balancerVault, 
            balancerPoolId
        ]);
        await proxy.deployed();
        userAccount = await unlockAccount("0xdd94018F54e565dbfc939F7C44a16e163FaAb331")
        
    })
    describe("deposit", async function(){
        it("should work with DUSD", async function(){
            const currentImplAddress = await upgrades.erc1967.getImplementationAddress(proxy.address);
            let swapCallData = await getParaswapCallData(parawswap_DUSD_src, currentImplAddress)
            let amount = ethers.utils.parseEther("10.0")
            
            // DAI allowance 
            // DAI deposit to the contract
            // check if the shares are minted

            const DUSD = await hre.ethers.getContractAt("MockERC20", dusd);
            await DUSD.connect(userAccount).approve(proxy.address, amount)

            let balance_before = await DAI.balanceOf(aArbDai)
            let deposit_tx = await proxy.connect(userAccount).deposit(
                dai,
                amount, 
                swapCallData
            )
            let balance_after = await DAI.balanceOf(aArbDai)
        })
        it("should work with DAI", async function(){
            const currentImplAddress = await upgrades.erc1967.getImplementationAddress(proxy.address);
            let swapCallData = await getParaswapCallData(parawswap_DAI_src,currentImplAddress)
            let amount = ethers.utils.parseEther("10.0")
            
            // DAI allowance 
            // DAI deposit to the contract
            // check if the shares are minted

            
            
            const DAI = await hre.ethers.getContractAt("MockERC20", dai);
            await DAI.connect(userAccount).approve(proxy.address, amount)

            let balance_before = await DAI.balanceOf(aArbDai)
            let deposit_tx = await proxy.connect(userAccount).deposit(
                dai,
                amount, 
                swapCallData
            )
            let balance_after = await DAI.balanceOf(aArbDai)
        })
    })
    describe("withdraw", async function(){
        beforeEach('deposit', async function(){
            const currentImplAddress = await upgrades.erc1967.getImplementationAddress(proxy.address);
            let swapCallData = await getParaswapCallData(parawswap_DAI_src,currentImplAddress)
            let amount = ethers.utils.parseEther("10.0")
            
            // DAI allowance 
            // DAI deposit to the contract
            // check if the shares are minted

            
            const DAI = await hre.ethers.getContractAt("MockERC20", dai);
            await DAI.connect(userAccount).approve(proxy.address, amount)

            let balance_before = await DAI.balanceOf(aArbDai)
            let deposit_tx = await proxy.connect(userAccount).deposit(
                dai,
                amount, 
                swapCallData
            )
            let balance_after = await DAI.balanceOf(aArbDai)
        })
        it("should work for DUSD", async function(){
            const DUSD = await hre.ethers.getContractAt("MockERC20", dusd);
            let balance_before = await DUSD.balanceOf(userAccount._address)
            await proxy.connect(userAccount).withdraw(dusd)
            let balance_after = await DUSD.balanceOf(userAccount._address)
        })

        it("should work for DAI", async function(){
            const DAI = await hre.ethers.getContractAt("MockERC20", dai);
            let balance_before = await DAI.balanceOf(userAccount._address)
            await proxy.connect(userAccount).withdraw(dai)
            let balance_after = await DAI.balanceOf(userAccount._address)
        })
    })
    
})