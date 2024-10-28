//SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {PriceConverter} from "./PriceConverter.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


//** A good practice to name storage variables as s_xxxx this is to assist gas optimization */
error FundMe__NotOwner();

contract FundMe {
    using PriceConverter for uint256;

    uint256 public constant MINIMUM_USD = 5e18;
    address private immutable i_owner;
    AggregatorV3Interface private s_priceFeed;

    constructor (address priceFeed) {
        i_owner = msg.sender;
        s_priceFeed = AggregatorV3Interface(priceFeed);
    }

    address[] public s_funders;
    mapping(address funder => uint256 amountFunded) public s_amountSent;

    function fund() public payable {
        require(
            msg.value.getConversionRate(s_priceFeed) >= MINIMUM_USD,
            "Didnt send enough!"
        );
        s_funders.push(msg.sender);
        s_amountSent[msg.sender] =  s_amountSent[msg.sender] + msg.value; // their aggregated funding
    }


    function cheaperWithdraw() public onlyOwner{
        uint256 fundersLength = s_funders.length; // doing so turns a storage variable into a memory variable (variable that is stored in a memory as the function call)
        for(uint256 funderIndex = 0; funderIndex<fundersLength; funderIndex ++){
            address funder = s_funders[funderIndex];
            s_amountSent[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }


    function withdraw() public onlyOwner {    //reading s_funders in storage as compared to reading it from memory(Cheapr Gas)
        for (uint256 funderIndex = 0; funderIndex < s_funders.length ; funderIndex++){ 
            address funder = s_funders[funderIndex];
            s_amountSent[funder] = 0;
        }
        s_funders = new address[](0);
        (bool callSuccess, ) = payable(msg.sender).call{value: address(this).balance}("");
        require(callSuccess, "Call failed");
    }   


        modifier onlyOwner() {
            require(msg.sender == i_owner, "Sender is not Owner!");
            // if ( msg.sender != i_owner) { revert NotOwner();}
            _;
        }

        receive() external payable{
            fund();
        }

        fallback() external payable{
            fund();
        }

        function getVersion() public view returns(uint256)  {
            return s_priceFeed.version();
        }

        /**
     * View/Pure Functions (Getters)
     */

        function getAddressToAmountFunded( address fundingAddress) external view returns (uint256){
            return s_amountSent[fundingAddress];
        }

        function getFunders(uint256 index) external view returns(address){
            return s_funders[index]; 
        }

        function getOwner() external view returns(address){
            return i_owner;
        }

        
    }
