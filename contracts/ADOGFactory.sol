// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import "./AlwaysDog.sol";
import "./BatchSwapper.sol";

// Add this interface at the top of the contract
interface IBatchSwapper {
    function transferOwnership(address) external;
    function setFeeCollector(address) external;
}

contract ADOGFactory is Ownable {
    // ProxyAdmin contract
    ProxyAdmin public proxyAdmin;
    
    // Events
    event ProxiesDeployed(
        address indexed deployer,
        address alwaysDog,
        address batchSwapper
    );

    constructor() {
        // Deploy ProxyAdmin
        proxyAdmin = new ProxyAdmin();
        proxyAdmin.transferOwnership(msg.sender);
    }

    /**
     * @dev Deploys AlwaysDog and BatchSwapper proxies and links them together
     * @param alwaysDogImpl Implementation address for AlwaysDog
     * @param batchSwapperImpl Implementation address for BatchSwapper
     * @param swapRouter Address of the PancakeSwap V3 router
     * @param tokenName Name of the token
     * @param tokenSymbol Symbol of the token
     * @return adogProxy Address of deployed AlwaysDog proxy
     * @return batchSwapperProxy Address of deployed BatchSwapper proxy
     */
    function deployProxies(
        address alwaysDogImpl,
        address batchSwapperImpl,
        address swapRouter,
        address _wbnb,
        string memory tokenName,
        string memory tokenSymbol
    ) external onlyOwner returns (address adogProxy, address batchSwapperProxy) {
        require(alwaysDogImpl != address(0), "Invalid ADOG implementation");
        require(batchSwapperImpl != address(0), "Invalid swapper implementation");
        require(swapRouter != address(0), "Invalid router address");
        require(bytes(tokenName).length > 0, "Empty token name");
        require(bytes(tokenSymbol).length > 0, "Empty token symbol");

        // Deploy AlwaysDog proxy
        bytes memory adogData = abi.encodeWithSelector(
            AlwaysDog.initialize.selector,
            tokenName,
            tokenSymbol
        );
        
        adogProxy = address(new TransparentUpgradeableProxy(
            alwaysDogImpl,
            address(proxyAdmin),
            adogData
        ));

        // Deploy BatchSwapper proxy
        bytes memory swapperData = abi.encodeWithSelector(
            BatchSwapper.initialize.selector,
            swapRouter,
            adogProxy,
            _wbnb
        );
        
        batchSwapperProxy = address(new TransparentUpgradeableProxy(
            batchSwapperImpl,
            address(proxyAdmin),
            swapperData
        ));

        // Set BatchSwapper as minter in AlwaysDog
        AlwaysDog(adogProxy).setMinter(batchSwapperProxy);
        // Set deployer as fee collector in BatchSwapper
        IBatchSwapper(batchSwapperProxy).setFeeCollector(msg.sender);

        // Transfer ownership of both contracts to deployer
        AlwaysDog(adogProxy).transferOwnership(msg.sender);
        IBatchSwapper(batchSwapperProxy).transferOwnership(msg.sender);

        emit ProxiesDeployed(msg.sender, adogProxy, batchSwapperProxy);

        return (adogProxy, batchSwapperProxy);
    }

    // Function to recover any stuck tokens
    function rescueTokens(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
        } else {
            IERC20 tokenContract = IERC20(token);
            uint256 balance = tokenContract.balanceOf(address(this));
            require(balance > 0, "No tokens to rescue");
            tokenContract.transfer(owner(), balance);
        }
    }
}
