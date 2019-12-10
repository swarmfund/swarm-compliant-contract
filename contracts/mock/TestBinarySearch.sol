pragma solidity ^0.5.0;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "../interfaces/ICurrencyRegistry.sol";


contract TestBinarySearch {

    using SafeMath for uint256;

    struct Balance {
        uint256 sequence;
        uint256 balance;
    }

    mapping(address => Balance[]) historicalBalance;

    function getAllBalances(address currency) public view returns (uint256[] memory) {
        
        for(uint256 i = 0; i < historicalBalance[currency].length; i++) {

        }

    }

    function addHistoricalBalance(address currency, uint256 balance, uint256 sequence) public returns(bool) {
        Balance memory bal;
        bal.sequence = sequence;
        bal.balance = balance;
        historicalBalance[currency].push(bal);
    }

    function getHistoricalBalance(
        uint256 _sequence,
        address _currency
    )
        public
        view
        returns (uint256)
    {
        Balance[] memory arr = historicalBalance[_currency];

        uint256 l;
        uint256 r = arr.length;
        uint256 mid;
        while (l < r) {
            mid = l + (r - l) / 2;
            // Check if x is present at mid
            if (arr[mid].sequence == _sequence)
                return arr[mid].balance;
            if (_sequence < arr[mid].sequence) {
                // If target is greater than previous
                // to mid, return closest of two
                if (mid > 0 && _sequence > arr[mid - 1].sequence) {
                    // return _getLower(arr[mid - 1].sequence, arr[mid].sequence, _sequence);
                    return arr[mid - 1].sequence;
                }
                /* Repeat for left half */
                r = mid;
            } else { // If target is greater than mid
                if (mid < arr.length - 1 && _sequence < arr[mid + 1].sequence) {
                    // return _getLower(arr[mid].sequence, arr[mid + 1].sequence, _sequence);
                    return arr[mid].sequence;
                }
                // update i
                l = mid + 1;
            }
        }
        return arr[mid].balance;
    }

}