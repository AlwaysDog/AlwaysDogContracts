// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ISwapRouter.sol";
import "./AlwaysDog.sol";

interface IWETH {
    function withdraw(uint256) external;
}

contract BatchSwapper is 
    Initializable, 
    OwnableUpgradeable, 
    ReentrancyGuardUpgradeable,
    PausableUpgradeable 
{
    ISwapRouter public swapRouter;
    address public WBNB; // Add WBNB address storage
    
    // Mapping to store supported pools (token => fee)
    mapping(address => uint24) public supportedPools;
    
    // Fee settings
    uint256 public swapFee;
    address public feeCollector;
    
    // BNB amount limitations
    uint256 public minBnbPerSwap;
    uint256 public maxBnbPerSwap;

    // AlwaysDog token contract
    AlwaysDog public alwaysDog;
    // Amount of ADOG to mint per swap
    uint256 public adogMintAmount;

    // Storage gap for future upgrades
    // 50 slots = 50 * 32 bytes = 1600 bytes of storage
    uint256[50] private __gap;
    
    // Events
    event PoolAdded(address token, uint24 fee);
    event PoolRemoved(address token);
    event SwapExecuted(address token, uint256 amountIn, uint256 amountOut);
    event FeeUpdated(uint256 oldFee, uint256 newFee);
    event FeeCollectorUpdated(address oldCollector, address newCollector);
    event SwapLimitsUpdated(
        uint256 minPerSwap,
        uint256 maxPerSwap
    );
    event ADOGMintAmountUpdated(uint256 oldAmount, uint256 newAmount);
    event ADOGMinted(address indexed user, uint256 amount);
    
    // Add constant for maximum fee
    uint256 public constant MAX_SWAP_FEE = 0.001 ether; // 0.001 BNB

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _swapRouter,
        address _alwaysDog,
        address _WBNB    // Add WBNB parameter
    ) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        swapRouter = ISwapRouter(_swapRouter);
        feeCollector = msg.sender;
        WBNB = _WBNB;    // Initialize WBNB address
        
        // Set default limits
        minBnbPerSwap = 0.002 ether;    // 0.002 BNB
        maxBnbPerSwap = 2 ether;      // 2 BNB

        // Initialize AlwaysDog settings
        alwaysDog = AlwaysDog(_alwaysDog);
        adogMintAmount = 10 * (10 ** 18); // 10 ADOG tokens
    }

    // Function to add supported pools
    function addPool(address token, uint24 fee) external onlyOwner {
        require(token != address(0), "Invalid token address");
        require(fee > 0, "Invalid fee");
        supportedPools[token] = fee;
        emit PoolAdded(token, fee);
    }

    // Function to remove supported pools
    function removePool(address token) external onlyOwner {
        require(supportedPools[token] > 0, "Pool not supported");
        delete supportedPools[token];
        emit PoolRemoved(token);
    }

    // Rename SwapRequest to BnbToTokenSwapRequest
    struct BnbToTokenSwapRequest {
        address tokenOut;
        uint256 bnbAmount;
    }

    // Function to set swap fee
    function setSwapFee(uint256 _newFee) external onlyOwner {
        require(_newFee > 0, "Fee must be greater than 0");
        require(_newFee <= MAX_SWAP_FEE, "Fee exceeds maximum");
        uint256 oldFee = swapFee;
        swapFee = _newFee;
        emit FeeUpdated(oldFee, _newFee);
    }

    // Function to set fee collector
    function setFeeCollector(address _newCollector) external onlyOwner {
        require(_newCollector != address(0), "Invalid fee collector address");
        address oldCollector = feeCollector;
        feeCollector = _newCollector;
        emit FeeCollectorUpdated(oldCollector, _newCollector);
    }

    // Function to set BNB limitations
    function setSwapLimits(
        uint256 _minPerSwap,
        uint256 _maxPerSwap
    ) external onlyOwner {
        require(_minPerSwap > 0, "Min amount must be > 0");
        require(_maxPerSwap >= _minPerSwap, "Max must be >= min");
        
        minBnbPerSwap = _minPerSwap;
        maxBnbPerSwap = _maxPerSwap;
        
        emit SwapLimitsUpdated(_minPerSwap, _maxPerSwap);
    }

    /**
     * @dev Updates the ADOG mint amount per swap
     * @param _newAmount New amount of ADOG to mint per swap
     */
    function setADOGMintAmount(uint256 _newAmount) external onlyOwner {
        uint256 oldAmount = adogMintAmount;
        adogMintAmount = _newAmount;
        emit ADOGMintAmountUpdated(oldAmount, _newAmount);
    }

    // Add function to update WBNB address
    function setWBNB(address _newWBNB) external onlyOwner {
        require(_newWBNB != address(0), "Invalid WBNB address");
        WBNB = _newWBNB;
    }

    // Update the function parameter to use the new struct name
    function batchSwapExactBNBForTokens(
        BnbToTokenSwapRequest[] calldata requests
    ) external payable nonReentrant whenNotPaused {
        require(msg.value >= swapFee, "Insufficient fee amount");
        require(requests.length > 0, "Empty swap requests");
        
        uint256 totalBNB = swapFee; // Start with fee amount
        
        // Calculate total BNB needed and validate amounts
        for (uint256 i = 0; i < requests.length; i++) {
            BnbToTokenSwapRequest memory req = requests[i];
            require(supportedPools[req.tokenOut] > 0, "Pool not supported");

            require(
                req.bnbAmount >= minBnbPerSwap,
                "Swap amount below minimum"
            );

            require(
                req.bnbAmount <= maxBnbPerSwap,
                "Swap amount exceeds maximum"
            );

            totalBNB += req.bnbAmount;
        }

        require(msg.value == totalBNB, "Incorrect BNB amount sent");

        if (swapFee > 0) {
            // Transfer fee to fee collector
            (bool success, ) = payable(feeCollector).call{value: swapFee}("");
            require(success, "Fee transfer failed");
        }

        // Mint ADOG tokens to the user
        alwaysDog.mint(msg.sender, adogMintAmount);
        emit ADOGMinted(msg.sender, adogMintAmount);

        // Perform swaps
        for (uint256 i = 0; i < requests.length; i++) {
            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: WBNB,    // Use WBNB instead of address(0)
                    tokenOut: requests[i].tokenOut,
                    fee: supportedPools[requests[i].tokenOut],
                    recipient: msg.sender,
                    deadline: block.timestamp + 300,
                    amountIn: requests[i].bnbAmount,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            uint256 amountOut = swapRouter.exactInputSingle{
                value: requests[i].bnbAmount
            }(params);

            emit SwapExecuted(requests[i].tokenOut, requests[i].bnbAmount, amountOut);
        }
    }

    // Add new struct for token to BNB swaps
    struct TokenToBnbRequest {
        address tokenIn;
        uint256 amountIn;
    }

    /**
     * @dev Swaps multiple tokens for BNB
     * @param requests Array of swap requests
     */
    function batchSwapExactTokensForBNB(
        TokenToBnbRequest[] calldata requests
    ) external nonReentrant whenNotPaused {
        require(requests.length > 0, "Empty swap requests");
        
        // Perform swaps
        for (uint256 i = 0; i < requests.length; i++) {
            TokenToBnbRequest memory req = requests[i];
            require(supportedPools[req.tokenIn] > 0, "Pool not supported");

            // Transfer tokens to this contract
            IERC20(req.tokenIn).transferFrom(
                msg.sender,
                address(this),
                req.amountIn
            );

            // Approve router
            IERC20(req.tokenIn).approve(address(swapRouter), req.amountIn);

            ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
                .ExactInputSingleParams({
                    tokenIn: req.tokenIn,
                    tokenOut: WBNB,
                    fee: supportedPools[req.tokenIn],
                    recipient: address(this), // Change recipient to this contract
                    deadline: block.timestamp + 300,
                    amountIn: req.amountIn,
                    amountOutMinimum: 0,
                    sqrtPriceLimitX96: 0
                });

            uint256 amountOut = swapRouter.exactInputSingle(params);
            
            // Unwrap WBNB to BNB and send to user
            IWETH(WBNB).withdraw(amountOut);
            (bool success,) = payable(msg.sender).call{value: amountOut}("");
            require(success, "BNB transfer failed");
            
            emit SwapExecuted(req.tokenIn, req.amountIn, amountOut);
        }
    }

    // Function to pause the contract
    function pause() external onlyOwner {
        _pause();
    }

    // Function to unpause the contract
    function unpause() external onlyOwner {
        _unpause();
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

    // Required to receive BNB
    receive() external payable {}

}
