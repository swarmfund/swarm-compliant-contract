pragma solidity ^0.5.10;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IPriceUSD.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";

/**
 * @title The Issuer Stake Offer Pool Contract
 * This contract allows the anyone to register as provider of SWM tokens.
 */
contract IssuerStakeOfferPool is IIssuerStakeOfferPool, Ownable {

    using SafeMath for uint256;

    // Setup variables that don't change

    address public src20Registry; // @TODO check why we need this
    uint256 public minTokens;
    uint256 public maxMarkup;
    uint256 public maxProviderCount;

    address public swarmERC20;
    address public uniswapUSDC;
    address public swmPriceOracle;

    // State variables that can change

    address public head;
    
    struct provider {
        uint256 tokens;
        uint256 markup;
        address previous;
        address next;
    }

    mapping(address => provider) public providerList;

    uint256 public providerCount;

    constructor(
        address _swarmERC20, 
        address _ethPriceOracle, 
        address _swmPriceOracle, 
        uint256 _minTokens,
        uint256 _maxProviderCount) 
    public {
        swmPriceOracle = _swmPriceOracle;
        swarmERC20 = _swarmERC20;
        uniswapUSDC = _ethPriceOracle;
        minTokens = _minTokens;
        maxProviderCount = _maxProviderCount;
    }

    function register(uint256 swmAmount, uint256 markup) external returns (bool) {

        require(swmAmount >= minTokens, 'Registration failed: offer more tokens!');
        require(providerCount < maxProviderCount, 'Registration failed: all slots full!');
        // require(markup <= maxMarkup, 'Registration failed: offer smaller markup!');

        providerList[msg.sender].tokens = swmAmount;
        providerList[msg.sender].markup = markup;

        _addToList(msg.sender);

        providerCount++;
        return true;
    }

    function _addToList(address provider) internal returns (bool) {

        // If we don't have any elements set it up as the first one
        if (head == address(0)) {
            providerList[provider].next = address(0);
            providerList[provider].previous = address(0);
            head = provider;
            return true;
        }

        // If we have at least one element, loop through the list, add new element to correct place
        address i = head;
        while(i != address(0)) {
            if (providerList[provider].markup <= providerList[head].markup) {

                if (i == head) {
                    head = provider;
                    providerList[provider].next = i;
                    providerList[provider].previous = address(0);
                }
                else {
                    providerList[providerList[provider].previous].next = providerList[provider].next;
                    providerList[providerList[provider].next].previous = providerList[provider].previous;                    
                }

                return true;
            }

            providerList[provider].previous = i;
            i = providerList[i].next;
        }

        // If the loop didn't place him, it means he's the last chap
        // His .previous has been set above
        providerList[provider].next = address(0);
        providerList[providerList[provider].previous].next = provider;
        
        return true;
    }

    function _removeFromList(address provider) internal returns (bool) {

        providerList[provider].tokens = 0;
        providerList[provider].markup = 0;
        providerList[providerList[provider].previous].next = providerList[provider].next;
        providerList[providerList[provider].next].previous = providerList[provider].previous;
        
        if (provider == head)
            head = address(0);
    }

    function unRegister() external returns (bool) {

        _removeFromList(msg.sender);

        providerCount--;
        return true;
    }

    function unRegister(address provider) external onlyOwner returns (bool) {

        _removeFromList(provider);

        providerCount--;
        return true;
    }

    function updateMinTokens(uint256 _minTokens) external onlyOwner {
        minTokens = _minTokens;
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

    function loopBuySWMTokens(uint256 numSWM, uint256 maxMarkup) public payable returns (bool) {

        // Convert figures
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * (swmPriceUSDnumerator / swmPriceUSDdenominator);

        uint256 ethPriceUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(1);
        uint256 receivedUSD = msg.value * ethPriceUSD;

        require(receivedUSD >= requiredUSD, 'Purchase failed: send more ETH!');

        // loop and collect tokens
        uint256 tokens;
        uint256 tokensCollected;
        uint256 tokenValueUSD;
        uint256 tokenValueETH;
        address i = head;

        while(i != address(0)) {
            
            if (providerList[i].markup > maxMarkup) {
                i = providerList[i].next;
                continue;
            }

            tokens = numSWM - tokensCollected >= providerList[i].tokens ? 
                     providerList[i].tokens : numSWM - tokensCollected;

            tokensCollected = tokensCollected + tokens;

            providerList[i].tokens = providerList[i].tokens - tokens;
            if(providerList[i].tokens == 0) {
                _removeFromList(i);
                providerCount--;
            }
            
            tokenValueUSD = tokens * (swmPriceUSDnumerator / swmPriceUSDdenominator);
            tokenValueETH = tokenValueUSD / ethPriceUSD;

            IERC20(swarmERC20).transferFrom(i, msg.sender, tokens);
            address(uint160(i)).transfer(tokenValueETH);

        }
   
    }

    function buySWMTokens(address account, uint256 numSWM) public payable returns (bool) {
        
        require(numSWM <= providerList[account].tokens, 'Purchase failed: offerer lacks tokens!');
        require(IERC20(swarmERC20).allowance(account, msg.sender) >= numSWM, 'Purchase failed: allowance not set!');

        // Calculate whether the price is good
        // @TODO convert to SafeMath when happy with logic
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * (swmPriceUSDnumerator / swmPriceUSDdenominator);

        uint256 ethPriceUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(1);
        uint256 receivedUSD = msg.value * ethPriceUSD;

        uint256 markup = receivedUSD / requiredUSD * 100;

        require(markup >= providerList[account].markup, 'Purchase failed: offered price too low!');
        
        IERC20(swarmERC20).transferFrom(account, msg.sender, numSWM);

    }

}