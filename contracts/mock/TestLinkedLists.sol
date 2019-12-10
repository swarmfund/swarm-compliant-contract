pragma solidity ^0.5.10;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "../interfaces/IUniswap.sol";
import "../interfaces/IPriceUSD.sol";
import "../interfaces/IIssuerStakeOfferPool.sol";

/**
 * @title The TestLinkedLists Contract
 *
 * This contract allows anyone to register as provider/seller of SWM tokens.
 * While registering, the SWM tokens are transferred from the provider to the
 * contract. The unsold SWM can be withdrawn at any point in time by unregistering.
 */
contract TestLinkedLists is Ownable {

    using SafeMath for uint256;

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
    )
    public {
    }

    function getList() external view returns (address[] memory) {
        address[] memory list = new address[](providerCount);
        // If we have at least one element, loop through the list, add new element to correct place
        address i = head;
        uint256 counter;
        while(i != address(0)) {
            list[counter] = i;
            i = providerList[i].next;
            counter++;
        }
        return list;
    }

    // one offer per address
    function register(uint256 swmAmount, uint256 markup) external returns (bool) {

        if(providerList[msg.sender].tokens > 0) {
            _removeFromList(msg.sender);
            providerCount = providerCount.sub(1);
        }

        providerCount = providerCount.add(1);

        providerList[msg.sender].tokens = swmAmount;
        providerList[msg.sender].markup = markup;

        if(providerList[msg.sender].previous != address(0) || 
           providerList[msg.sender].next != address(0) ||
           msg.sender == head)
            return true; // we exit so as to not add him twice

        _addToList2(msg.sender);

        return true;
    }

    function unRegister(address provider) external onlyOwner returns (bool) {
        _removeFromList(provider);

        providerCount = providerCount.sub(1);
        return true;
    }

    // Add an element to the sorted (ascending) linked list of elements
    function _addToList1(address provider) 
    public returns (bool) {

        // If we don't have any elements set it up as the first one
        if (head == address(0)) {
            head = provider;
            return true;
        }

        if (providerList[head].markup >= providerList[provider].markup) {
            if (providerList[provider].next != address(0) || providerList[provider].previous != address(0)) {
                providerList[providerList[provider].previous].next = providerList[provider].next;
            }

            providerList[provider].next = head;
            providerList[providerList[provider].next].previous = provider;
            head = provider;
        } else {
            address current = head;
            while (
                providerList[current].next != address(0) 
                && providerList[providerList[current].next].markup < providerList[provider].markup
            ) 
            {
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

        return true;
    }

    // Add an element to the sorted (ascending) linked list of elements
    function _addToList2(address provider) 
    public returns (bool) {

        if(head == address(0)) {
            head = provider;
            return true;
        }
        // If we have at least one element, loop through the list, add new element to correct place
        address i = head;
        while(i != address(0)) {

            // If we are smaller or equal than the current element, insert us before it
            if (providerList[provider].markup <= providerList[i].markup) {

                if (i == head) { // placing in front
                    providerList[head].previous = provider;
                    providerList[provider].next = head;
                    providerList[provider].previous = address(0);
                    head = provider;
                }
                else { // placing between two others
                    providerList[provider].next = i;
                    providerList[provider].previous = providerList[i].previous;
                    providerList[providerList[i].previous].next = provider;
                    providerList[i].previous = provider;
                }

                return true;
            }
            // we do this because the next line could set i to address(0)
            // but we want to preserve information who was last before 0
            providerList[provider].previous = i;

            i = providerList[i].next;
        }

        // If the loop didn't place him, it means he's the last chap
        // His .previous has been set above, his .next is 0 (set by default),
        // here we just repoint the old last element to this one
        providerList[providerList[provider].previous].next = provider;

        return true;
    }

    function _removeFromList(address provider) internal returns (bool) {
        if (provider == head)
            head = providerList[provider].next;
        providerList[providerList[provider].previous].next = providerList[provider].next;
        providerList[providerList[provider].next].previous = providerList[provider].previous;
        delete (providerList[provider]);
        return true;
    }

}
