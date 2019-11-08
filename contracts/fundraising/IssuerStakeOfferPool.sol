pragma solidity ^0.5.10;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "../interfaces/IPriceUSD.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";

/**
 * @title The Issuer Stake Offer Pool Contract
 * This contract allows the anyone to register as provider of SWM tokens.
 */
contract IssuerStakeOfferPool is IIssuerStakeOfferPool {

    using SafeMath for uint256;

    address public src20Registry;
    uint256 public minAmountNeeded;
    uint256 public maxMarkup;

    struct provider {
        uint256 tokens;
        uint256 markup;
    }

    mapping(address => provider) providerList;

    address swarmERC20;
    address uniswapUSDC;
    address swmPriceOracle;

    constructor(address _swarmERC20, address _ethPriceOracle, address _swmPriceOracle) public {
        swmPriceOracle = _swmPriceOracle;
        swarmERC20 = _swarmERC20;
        uniswapUSDC = _ethPriceOracle;
    }

    function register(uint256 swmAmount, uint256 markup) external returns (bool) {

        providerList[msg.sender].tokens = swmAmount;
        providerList[msg.sender].markup = markup;

        return true;
    }

    function unRegister() external returns (bool) {

        providerList[msg.sender].tokens = 0;
        providerList[msg.sender].markup = 0;

        return true;
    }

    function isStakeOfferer(address account) external view returns (bool) {
        return providerList[account].tokens > 0;
    }

    function getSWMPriceETH(address account, uint256 numSWM) external returns (uint256) {
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * (swmPriceUSDnumerator / swmPriceUSDdenominator);

        uint256 ethPriceUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(1);
        return requiredUSD / ethPriceUSD * providerList[account].markup;
    }

    function buySWMTokens(address account, uint256 numSWM) external payable returns (bool) {
        
        require(numSWM <= providerList[account].tokens, 'Purchase failed: offerer lacks tokens!');
        require(IERC20(swarmERC20).allowance(account, msg.sender) >= numSWM, 'Purchase failed: allowance not set!');

        // Calculate whether the price is good
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * (swmPriceUSDnumerator / swmPriceUSDdenominator);

        uint256 ethPriceUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(1);
        uint256 sentUSD = msg.value * ethPriceUSD;

        uint256 markup = sentUSD / requiredUSD * 100;

        require(markup >= providerList[account].markup, 'Purchase failed: offered price too low!');
        
        IERC20(swarmERC20).transferFrom(account, msg.sender, numSWM);

    }

}