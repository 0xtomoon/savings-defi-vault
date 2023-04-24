pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

abstract contract Test is TransparentUpgradeableProxy {
    string public constant message = "Hello, world!";

    constructor() {
        
    }
}