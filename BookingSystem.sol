// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "./Flight.sol";
import "./BookingContract.sol";

interface BookingSystem {

    function initiateBooking(string memory _flightNumber, Flight.SeatCategory _seatCategory) 
        external 
        payable
        returns(string memory);

    function getBookingData(address customer) 
        external view
        returns (BookingContract.BookingData memory);

    function cancelBooking() external;

    function claimRefund() external;

    function cancelFlight(string memory _flightNumber) external;

    function updateFlightStatus(string memory _flightNumber, Flight.FlightState _state, uint _delayInHours) external ;

    function getFlightData(string memory _flightNumber) external view returns (Flight.FlightData memory);

}