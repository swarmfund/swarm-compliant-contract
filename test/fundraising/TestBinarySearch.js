const {BN, constants, expectEvent, shouldFail} = require('openzeppelin-test-helpers');
const crypto = require('crypto');
const moment = require('moment');
const helpers = require('../token/helpers');
const {encodeTransfer} = require('../token/utils');

const TestBinarySearch = artifacts.require('TestBinarySearch');

var testdata = [
    // seq, bal
       [0,0],
       [3,12],
       [4,13],
       [5,14],
       [10,15],
       [15,16],
       [20,17],
       [21,18]
   ];

contract('SwarmPoweredFundraise', async function ([_, whitelistManager, currency, owner, issuer, contributor]) {

  beforeEach(async function () {

    this.testBinarySearch = await TestBinarySearch.new({from: owner});

    for(let i = 0; i < testdata.length; i++) {
        let seq = testdata[i][0];
        let bal = testdata[i][1];
        await this.testBinarySearch.addHistoricalBalance(currency, bal, seq);
    }

  });

  describe('Test balances returned for various sequences', function () {

    it('should return exact or lower balance every time', async function () {

        console.log('EXPECTED vs ACTUAL:');

        let bal = 0;
        let seq = 0;
        let j = 0;
        let balact = 0;
        for(let i = 0; i < 25; i++) {
            seq = testdata[j][0];
            if(i == seq) {
                bal = testdata[j][1];
                if(j < testdata.length - 1)
                    j++;
            }
            balact = await this.testBinarySearch.getHistoricalBalance(i, currency);
            console.log('i:', i, 'bal expected:', bal, 'bal actual:', balact.toString(), bal == balact);
          }

          //console.log('ACTUAL:');

        // for(let i=0; i<25; i++) {
        //   let bal = await this.testBinarySearch.getHistoricalBalance(i, currency);
        //   console.log('i:', i, 'bal:', bal.toString());
        // }

    });

  }); // describe

});
