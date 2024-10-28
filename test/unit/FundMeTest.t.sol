//SPDX-License-Identifier: MIT

pragma solidity ^0.8.8;

import {Test, console} from "forge-std/Test.sol";
import {FundMe} from "../../src/FundMe.sol";
import{DeployFundMe} from "../../script/DeployFundMe.s.sol";


contract FundMeTest is Test{


    FundMe fundMe;
    
    address USER = makeAddr("user");

    uint256 constant SEND_VALUE = 0.1 ether; //10000000000000000
    uint256 constant STARTING_BALANCE = 10 ether; 
    uint256 constant GAS_PRICE = 1; 

    function setUp() external {   //setup function will always be running 1st in test file!

        //fundMe = new FundMe(0x694AA1769357215DE4FAC081bf1f309aDC325306);
        DeployFundMe deployFundMe = new DeployFundMe();
        fundMe = deployFundMe.run();
        vm.deal(USER, STARTING_BALANCE);
    }

    function testMINIMUMDollarIsFive() public {
        assertEq(fundMe.MINIMUM_USD(), 5e18);
    }

    function testOwnerIsMsgSender() public {
    

        assertEq(fundMe.getOwner() , msg.sender);
    }

    function testPriceFeedVersionIsAccurate() public{
        uint256 version = fundMe.getVersion();
        assertEq (version, 4);
    }

    function testFundFailsWithoutEnoughETH()public{
        vm.expectRevert(); //the next line should revert(to test if it is reverting)
        fundMe.fund();
    }

    function testFundUpdatesFundedDataStructure() public {
        
        vm.prank(USER); //The next trx is sent by user
        fundMe.fund{value: SEND_VALUE}();

        uint256 amountFunded = fundMe.getAddressToAmountFunded(USER);
        assertEq(amountFunded, SEND_VALUE );
    }

    function testAddsFunderToArrayOfFunders() public {
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        address funder = fundMe.getFunders(0); //This test function gets reset every time hence why put index = 0
        assertEq(funder, USER);
    }

    modifier funded (){
        vm.prank(USER);
        fundMe.fund{value: SEND_VALUE}();
        _;
    }

    function testOnlyOwnerCanWithdraw() public funded {
        

        vm.expectRevert(); /**  so this code will apply to fundMe.withdraw() straight not vm.prank(), 
         coz vm.prank is a vm cheat code and it does not apply to vm cheat codes*/
        vm.prank(USER);
        fundMe.withdraw();
    }

    function testWithdrawWithASingleFunder() public funded {

        //Arrange
        uint256 startingOwnerBalance = fundMe.getOwner().balance;
        uint256 startingFundMeBalance = address(fundMe).balance;

        //Act
        vm.prank(fundMe.getOwner()); // coz only the owner can do withdrawal
        fundMe.withdraw();

        //Assert
        uint256 endingOwnerBalance = fundMe.getOwner().balance;
        uint256 endingFundMeBalance = address(fundMe).balance;
        assertEq(endingFundMeBalance, 0);
        assertEq(startingFundMeBalance + startingOwnerBalance, endingOwnerBalance);

    }

    function testWithdrawFromMultipleFunders() public funded {

        //Arrange 

        uint160 numberOfFunders = 10;  // this needs to change to uint160 (same bytes as an address), applies when want to use numbers to generate addresses 
        uint160 startingFunderIndex = 1; 
        for(uint160 i = startingFunderIndex; i < numberOfFunders; i++){
            //vm.prank (new address) set the caller to the new address
            //vm.deal (new address) set/ send eth to the new address
            // to generate new address, we could do ie: adddress(0) or address(2) etc.
            //hoax is a forge.std method, combines both prank and deal
            hoax(address(i), SEND_VALUE);
            //fund the fundMe
            fundMe.fund{value: SEND_VALUE}();
        }
        uint256 startingFundMeBalance  = address(fundMe).balance;
        uint256 startingOwnerBalance  = fundMe.getOwner().balance;

        //Act
       // uint256 gasStart = gasleft(); //gas left() is a built it function of Solidity, shows how much gas is left in your transaction call
       // vm.txGasPrice(GAS_PRICE);
        vm.startPrank(fundMe.getOwner()); // startPrank is something like startBroadcast, 
        //anything in betweem startPrank and stopPrank is going to pretend to be the address in getOwner()
        fundMe.withdraw();
        vm.stopPrank();

       // uint256 gasEnd = gasleft();
        //uint256 gasUsed = (gasStart - gasEnd)*tx.gasprice; //tx.gasprice another built in func from Solidity, tells you the current gas price
        //console.log(gasUsed);

        //Assert
        assert(address(fundMe).balance == 0); //assert testing the condition must always be true
        assert(startingFundMeBalance + startingOwnerBalance == fundMe.getOwner() .balance);
    }
}