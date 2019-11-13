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

    address public src20Registry; // @TODO check why we need this - Answer: The idea was to do stakeAndMint here, we can discuss later
    uint256 public minTokens;
    uint256 public maxMarkup;
    uint256 public maxProviderCount;

    address public swarmERC20;
    address public uniswapUSDC;
    address public swmPriceOracle;

    // State variables that can change

    address public head;

    struct Provider {
        uint256 tokens;
        uint256 markup;
        address previous;
        address next;
    }

    mapping(address => Provider) public providerList;

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

        _addToList(msg.sender, markup);
        providerList[msg.sender].tokens = swmAmount;
        providerList[msg.sender].markup = markup;

        providerCount++;
        return true;
    }

    // Add an element to the sorted (ascending) linked list of elements
    function _addToList(address provider, uint256 _markup) internal returns (bool) {

        // If we don't have any elements set it up as the first one
        if (head == address(0)) {
            head = provider;
            return true;
        }


        if (providerList[head].markup >= _markup) {
            if (providerList[provider].next != address(0) || providerList[provider].previous != address(0)) {
                providerList[providerList[provider].previous].next = providerList[provider].next;
            }

            providerList[provider].next = head;
            providerList[providerList[provider].next].previous = provider;
            head = provider;
        } else {
            address current = head;
            while (providerList[current].next != address(0) && providerList[providerList[current].next].markup < _markup) {
                current = providerList[current].next;
            }

            if (providerList[current].next != provider) {
                if (providerList[provider].next != address(0) || providerList[provider].previous != address(0)) {
                    providerList[providerList[provider].previous].next = providerList[provider].next;
                }

                providerList[provider].next = providerList[current].next;

                if (providerList[current].next != address(0)) {
                    providerList[providerList[provider].next].previous = provider;
                }

                providerList[current].next = provider;
                providerList[provider].previous = current;
            }
        }

        //            // If we have at least one element, loop through the list, add new element to correct place
        //        address i = head;
        //        while(i != address(0)) {
        //
        //            // If we are smaller or equal than the current element, insert us before it
        //            if (providerList[provider].markup <= providerList[head].markup) {
        //
        //                if (i == head) {
        //                    head = provider;
        //                    providerList[provider].next = i;
        //                    providerList[provider].previous = address(0);
        //                }
        //                else {
        //                    providerList[providerList[provider].previous].next = providerList[provider].next;
        //                    providerList[providerList[provider].next].previous = providerList[provider].previous;
        //                }
        //
        //                return true;
        //            }
        //
        //            providerList[provider].previous = i;
        //            i = providerList[i].next;
        //        }
        //
        //        // If the loop didn't place him, it means he's the last chap
        //        // His .previous has been set above, his .next is 0 (set by default),
        //        // here we just repoint the old last element to this one
        //        providerList[providerList[provider].previous].next = provider; //this line???

        return true;
    }

    function _removeFromList(address provider) internal returns (bool) {
        providerList[providerList[provider].previous].next = providerList[provider].next;
        providerList[providerList[provider].next].previous = providerList[provider].previous;
        delete (providerList[provider]);

        if (provider == head) {
            delete head;
        }

        return true;
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

    // Should this apply retroactively, with a loop?
    function updateMinTokens(uint256 _minTokens) external onlyOwner {
        minTokens = _minTokens;
    }

    function isStakeOfferer(address account) external view returns (bool) {
        return providerList[account].tokens > 0;
    }

    // Get how much ETH we need to spend to get numSWM from a specific account
    // Get the market price of SWM and apply the account's markup
    function getSWMPriceETH(address account, uint256 numSWM) external returns (uint256) {
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * swmPriceUSDnumerator / swmPriceUSDdenominator;
        uint256 requiredETH = IUniswap(uniswapUSDC).getEthToTokenOutputPrice(requiredUSD);
        return requiredETH * providerList[account].markup;
        // @TODO their need to be some kind of precisions
    }

    // Loop through the linked list of providers, buy SWM tokens from them until we have enough
    function loopBuySWMTokens(uint256 numSWM, uint256 _maxMarkup) public payable returns (bool) {
        // Convert figures 
        // @TODO calculations are all wrong, we don't have a market here, but a type of a bonding curve
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * swmPriceUSDnumerator / swmPriceUSDdenominator;

        uint256 receivedUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(msg.value);
        require(receivedUSD >= requiredUSD, 'Purchase failed: send more ETH!');

        // loop and collect tokens
        uint256 tokens;
        uint256 tokensCollected;
        uint256 tokenValueUSD;
        uint256 tokenValueETH;
        address i = head;
        // @TODO check looping, we should either go from 0 -> head or to head -> 0...
        while (i != address(0)) {

            // If this one is too expensive, skip to the next
            //            if (providerList[i].markup > maxMarkup) {
            //                i = providerList[i].next;
            //                continue;
            //            }
            // no need for this, we have require at register

            // Take all his tokens, or only a part of them
            if (numSWM - tokensCollected >= providerList[i].tokens) {
                tokens = providerList[i].tokens;
            } else {
                tokens = numSWM - tokensCollected;
            }

            //            tokens = numSWM - tokensCollected >= providerList[i].tokens ?
            //                     providerList[i].tokens : numSWM - tokensCollected;

            tokensCollected = tokensCollected + tokens;

            tokenValueUSD = tokens * swmPriceUSDnumerator / swmPriceUSDdenominator;
            tokenValueETH = IUniswap(uniswapUSDC).getTokenToEthInputPrice(tokenValueUSD);

            IERC20(swarmERC20).transferFrom(i, msg.sender, tokens);
            address(uint160(i)).transfer(tokenValueETH);

            i = providerList[i].next;

            // this needs to be after so we dont delete .next;
            providerList[i].tokens = providerList[i].tokens - tokens;
            if (providerList[i].tokens == 0) {
                _removeFromList(i);
                providerCount--;
            }
        }

        return true;
    }

    function buySWMTokens(address account, uint256 numSWM) public payable returns (bool) {

        require(numSWM <= providerList[account].tokens, 'Purchase failed: offerer lacks tokens!');
        require(IERC20(swarmERC20).allowance(account, msg.sender) >= numSWM, 'Purchase failed: allowance not set!');

        // Calculate whether the price is good
        // @TODO convert to SafeMath when happy with logic
        (uint256 swmPriceUSDnumerator, uint256 swmPriceUSDdenominator) = IPriceUSD(swmPriceOracle).getPrice();
        uint256 requiredUSD = numSWM * (swmPriceUSDnumerator / swmPriceUSDdenominator);

        // Not the same as on a deep market. @TODO check with client if this is OK
        uint256 receivedUSD = IUniswap(uniswapUSDC).getTokenToEthOutputPrice(msg.value);

        uint256 markup = receivedUSD / requiredUSD * 100;
        // @TODO 100 is precision, move to variable.

        require(markup >= providerList[account].markup, 'Purchase failed: offered price too low!');

        require(IERC20(swarmERC20).transferFrom(account, msg.sender, numSWM), "Purchase failed: SWM token transfer failed!");

        return true;
    }

}
