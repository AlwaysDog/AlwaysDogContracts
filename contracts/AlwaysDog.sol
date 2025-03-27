// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract AlwaysDog is 
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable
{
    // Token decimals
    uint8 private constant _decimals = 18;
    
    // Maximum supply
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * (10 ** 18); // 1 billion tokens
    
    // Minter address
    address public minter;
    
    // Events
    event TokensMinted(address indexed to, uint256 amount);
    event MinterUpdated(address indexed oldMinter, address indexed newMinter);
    
    // Storage gap for future upgrades
    uint256[50] private __gap;
    
    // Modifiers
    modifier onlyMinter() {
        require(msg.sender == minter, "Caller is not the minter");
        _;
    }
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize(
        string memory name,
        string memory symbol
    ) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        
        // Set deployer as initial minter
        minter = msg.sender;
        emit MinterUpdated(address(0), msg.sender);
    }
    
    /**
     * @dev Returns the number of decimals used for token precision
     */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Sets the minter address. Only callable by owner.
     * @param _minter New minter address
     */
    function setMinter(address _minter) external onlyOwner {
        require(_minter != address(0), "Cannot set minter to zero address");
        address oldMinter = minter;
        minter = _minter;
        emit MinterUpdated(oldMinter, _minter);
    }
    
    /**
     * @dev Mints new tokens. Only callable by minter.
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyMinter {
        require(to != address(0), "Cannot mint to zero address");
        require(totalSupply() + amount <= MAX_SUPPLY, "Would exceed max supply");
        
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}
