// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "./Flight.sol";

/// @author GreatLearningGroup3
/// @title BookingContract holding customer booking details
contract BookingContract {
    enum BookingState {INITIATED, PENDING, CONFIRMED, CANCELLED, CLAIM_REFUNDED}

    struct BookingData {
        address customer;
        string confirmationId;
	    address airlines;
        BookingState state;
        string comment;
        Flight.SeatCategory seatCategory;
        string flightNumber;
        uint cancelPenalty;
        uint cancelRefund;
        uint delayPenalty;
        uint delayRefund;
    }

    BookingData bookingData;
    uint val;

    constructor(address _customer, address _airlines, uint _val) {
        bookingData = BookingData({
                customer: _customer,
                confirmationId: '',
                airlines: _airlines,
                state: BookingState.INITIATED,
                comment: '',
                seatCategory: Flight.SeatCategory.ECONOMY,
                flightNumber: '',
                cancelPenalty: 0,
                cancelRefund: 0,
                delayPenalty: 0,
                delayRefund: 0
        });
        val += _val;
    }

	/// Confirms ticket booking and sets rest of the booking details
	/// @param _customer Customer for which booking is to be confirmed
	/// @param _seatCategory Seat category requested by the customer
	/// @param _flightNumber Flight for which booking is to be done
    function bookTicket(address _customer, Flight.SeatCategory _seatCategory, string memory _flightNumber) public returns (string memory) {
        bookingData.confirmationId = "CONF1233455";
        bookingData.customer = _customer;
        bookingData.seatCategory = _seatCategory;
        bookingData.flightNumber = _flightNumber;
        bookingData.state = BookingState.CONFIRMED;

        bookingData.comment = string(abi.encodePacked("Booking confirmed with confirmation id ", bookingData.confirmationId, " for the flight ", _flightNumber));
        return bookingData.comment;
    }

	/// Get booking details for given customer
    function getBookingData() public view returns (BookingData memory){
        return bookingData;
    }

	/// Cancel booking for the confirmationId provided
	function cancelBooking(uint penalty, uint refundAmt) public {
       bookingData.cancelPenalty = penalty;
       bookingData.cancelRefund = refundAmt;
       bookingData.state = BookingState.CANCELLED;
       bookingData.comment = string(abi.encodePacked("Cancellation of Booking initiated by the customer with confirmation id ", bookingData.confirmationId));
    }

    function claimRefund(uint penalty, uint refundAmt) public {
       bookingData.state = BookingState.CLAIM_REFUNDED;
       bookingData.delayPenalty = penalty;
       bookingData.delayRefund = refundAmt;
       bookingData.comment = string(abi.encodePacked("Claim Refund process initiated by the customer with confirmation id ", bookingData.confirmationId));
    }

    function updateBookingState(BookingState _state) public{
        bookingData.state = _state;
    }

    function flightCancelled() public {
        bookingData.state = BookingState.CANCELLED;
        bookingData.comment = string(abi.encodePacked("Booking cancelled for the customer ", msg.sender,
        "with confirmation id ", bookingData.confirmationId));
    }

    function getValue() public view returns(uint) {
        return val;
    }
}

