// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.13;

import "./Flight.sol";
import "./BookingContract.sol";
import "./BookingSystem.sol";


/**
 * @title BookingServer
 * @dev This contract serves as an abtraction for two entities namely airlines and its passengers 
 * for performing various flight and its booking activities.
 *
 * For an Airline, flight activities comprises of updating flight status, view flight booking list
 * For a Passenger, flight activities comprises of booking flight ticket, cancel booking
 *
 * NOTE: This contract assumes that ETH to be used for tranfer of funds between entities. Also
 * exact value of the ticket in ethers is expected.
 */

contract BookingServer is BookingSystem{

    Flight flight;
    address payable airlines;
    bool flightStateUpdated = false;

	event AmountTransferred(address from, address to, uint amountInEther, string transferReason);
    event cancelTransferred(address from, address to, uint amountInEther, uint256 currentTime, string transferReason);
    event BookingComplete(address customer, string flightId);
    event FlightCancelled(address airlines, string flightId);

    mapping(uint => uint) private cancelpenaltyMap;
    mapping(uint => uint) private delaypenaltyMap;
    mapping(address => BookingContract) private bookings;
    address[] customers;

	modifier onlyCustomer(){
        require(msg.sender != airlines, "Only customer can do this action");
        _;
    }

    modifier onlyAirlines() {
        require(msg.sender == airlines, "Only airlines can do this action");
        _;
    }

    modifier onlyValidAddress(address addr) {
        require(addr != address(0));
        _;
    }

    modifier onlyValidFlightNumberAndState(string memory _flightNumber) {
        Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);
        require(bytes(flightData.flightNumber).length > 0, "Invalid flight number");
        require(flightData.state != Flight.FlightState.CANCELLED 
        && flightData.state != Flight.FlightState.DEPARTED, "Flight is Cancelled");
        _;
    }

    modifier validBookingAndState(address _customer, BookingContract.BookingState _state){
        BookingContract.BookingData memory bookingData = bookings[_customer].getBookingData();
        require(bytes(bookingData.flightNumber).length > 0, "Booking not found for this customer");
        require(bookingData.state == _state, "Booking is not in a valid state");
        _;
    }

    modifier onlyExactTicketAmount(string memory _flightNumber) {
        Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);
        require(msg.value == flightData.ethAmount *10**18, "Exact booking ethers needed");
        _;
    }

	modifier onlySufficientFunds() {
		require(msg.sender.balance > msg.value, "Insufficient funds to book the ticket");
		_;
	}

	constructor() {
        flight = new Flight();
        flight.populateFlights();
        airlines = payable(msg.sender);
     
        //Penalties for cancelling the ticket at different times before the scheduled flight time
        // Penalty for Cancelling between 2 to 12 hours is 80% of ticket price, between 12 to 24 hours is 60%, between 24 to 48 hours is 40%
        cancelpenaltyMap[2] = 80;
        cancelpenaltyMap[12] = 60;
        cancelpenaltyMap[24] = 40;

        //Different Penalties for different ranges of flight delay
        // Penalty for delaying the flight by 2 to 4 hours is 20% of ticket price, by 4 to 6 hours is 40%, by 6 to 8 hours is 60%
        delaypenaltyMap[2] = 20;
        delaypenaltyMap[4] = 40;
        delaypenaltyMap[6] = 60;
    }

    function initiateBooking(string memory _flightNumber, Flight.SeatCategory _seatCategory)
        public
        payable
        onlyCustomer
        onlySufficientFunds
		onlyValidFlightNumberAndState(_flightNumber) returns(string memory){

        BookingContract booking = new BookingContract(msg.sender, airlines, msg.value);
        bookings[msg.sender] = booking;
        customers.push(msg.sender);

        //emit Addresses(address(this), address(booking), airlines, msg.sender);
        //emit Balances(address(this).balance, address(booking).balance, airlines.balance, msg.sender.balance);
		emit AmountTransferred(msg.sender, address(booking), msg.value, "Booking amount");

        Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);
        payable(airlines).transfer(flightData.ethAmount*10**18);
        string memory bookingComment = booking.bookTicket(msg.sender, _seatCategory, _flightNumber);
        //emit Balances(address(this).balance, address(booking).balance, airlines.balance, msg.sender.balance);
		emit BookingComplete(msg.sender, _flightNumber);
        return bookingComment;
    }

	function getBookingData(address customer)
        public view
        onlyAirlines returns (BookingContract.BookingData memory) {
        return bookings[customer].getBookingData();
    }

    function cancelBooking()
        public
        onlyCustomer
        validBookingAndState(msg.sender, BookingContract.BookingState.CONFIRMED){
        uint penalty;
        uint refundAmt;

         //Retrieve the booking based on either customer address
        BookingContract.BookingData memory bookingData = bookings[msg.sender].getBookingData();
        Flight.FlightData memory flightData = flight.getFlightData(bookingData.flightNumber);

        require(flightData.state == Flight.FlightState.ON_TIME || flightData.state == Flight.FlightState.DELAYED);

        //Requires current time is 2 hours before the flight time
        require(block.timestamp < flightData.flightTime - 2 hours, "There is less than 2 hours for flight departure. Hence can't cancel the ticket");

        //Calculate Refund and Penalty
        //Customer triggers cancellation before 2 to 12 hours of flight departure
        if((block.timestamp < flightData.flightTime - 2 hours) && (block.timestamp > flightData.flightTime - 12 hours)){
            penalty = (cancelpenaltyMap[2]*flightData.ethAmount)/100;
            refundAmt = flightData.ethAmount - penalty;
        //Customer triggers cancellation before 12 to 24 hours of flight departure
        } else if((block.timestamp < flightData.flightTime - 12 hours) && (block.timestamp > flightData.flightTime - 24 hours)){
            penalty = (cancelpenaltyMap[12]*flightData.ethAmount)/100;
            refundAmt = flightData.ethAmount - penalty;
        //Customer triggers cancellation before 24 to 48 hours of flight departure
        } else if((block.timestamp < flightData.flightTime - 24 hours) && (block.timestamp > flightData.flightTime - 48 hours)){
            penalty = (cancelpenaltyMap[24]*flightData.ethAmount)/100;
            refundAmt = flightData.ethAmount - penalty;
        //Customer triggers cancellation before 2 days of flight departure
        } else {
            //full refund
            refundAmt = flightData.ethAmount;
        }

        payable(airlines).transfer(penalty*10**18);
        emit AmountTransferred(address(this), airlines, penalty, "Contract transferred the penalty to the airlines");
        payable(msg.sender).transfer(refundAmt*10**18);
		emit AmountTransferred(address(this), msg.sender, penalty, "Contract transferred refund to the customer");
        bookings[msg.sender].cancelBooking(penalty, refundAmt);
    }

    function claimRefund()
        public
        onlyCustomer
        validBookingAndState(msg.sender, BookingContract.BookingState.CONFIRMED){
        uint penalty;
        uint refundAmt;

        BookingContract.BookingData memory bookingData = bookings[msg.sender].getBookingData();
        Flight.FlightData memory flightData = flight.getFlightData(bookingData.flightNumber);
        // require (block.timestamp > flightData.departureTime + 24 hours, "Claim Refund to be done only 24 hrs after the flight departure time");
        if(flightData.state == Flight.FlightState.CANCELLED || !flightStateUpdated){
           //full refund to the customer
           refundAmt = flightData.ethAmount;
        } else if(flightData.state == Flight.FlightState.DELAYED){
           //Calculate the refund based on delay time and refund to customer
           //Flight is delayed by 2 to 4 hours
            if((flightData.departureTime - flightData.flightTime > 2 hours) && (flightData.departureTime - flightData.flightTime <= 4 hours)){
                penalty = (delaypenaltyMap[2]*flightData.ethAmount)/100;
                refundAmt = flightData.ethAmount - penalty;
            //Flight is delayed by 4 to 6 hours
            } else if((flightData.departureTime - flightData.flightTime > 4 hours) && (flightData.departureTime - flightData.flightTime <= 6 hours)){
                penalty = (delaypenaltyMap[4]*flightData.ethAmount)/100;
                refundAmt = flightData.ethAmount - penalty;
            //Flight is delayed by 6 to 8 hours
            } else if((flightData.departureTime - flightData.flightTime > 6 hours) && (flightData.departureTime - flightData.flightTime <= 8 hours)){
                penalty = (delaypenaltyMap[6]*flightData.ethAmount)/100;
                refundAmt = flightData.ethAmount - penalty;
            //Flight is delayed by more than 8 hours
            } else if (flightData.departureTime - flightData.flightTime > 8 hours){
                //Full refund
                refundAmt = flightData.ethAmount;
            }
        }
        bookings[msg.sender].claimRefund(penalty, refundAmt);
        payable(airlines).transfer(penalty*10**18);
        payable(msg.sender).transfer(refundAmt*10**18);
		emit AmountTransferred(msg.sender, airlines, penalty, "Booking Contract transferred the penalty to the airlines and refunded to the customer");
    }

   function cancelFlight(string memory _flightNumber)
        public
		onlyAirlines
        onlyValidFlightNumberAndState(_flightNumber) {

        require(block.timestamp <= (flight.getFlightData(_flightNumber).flightTime - 24 hours), "Flight can only be cancelled, 24 hrours before flight start time");

        flight.setFlightState(_flightNumber, Flight.FlightState.CANCELLED, 0);
        emit FlightCancelled(msg.sender, _flightNumber);
        Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);

        for(uint i = 0; i < customers.length; i++) {
            if (bookings[customers[i]].getBookingData().state == BookingContract.BookingState.CONFIRMED) {
                payable(customers[i]).transfer(flightData.ethAmount*10**18);
                bookings[customers[i]].flightCancelled();
                emit AmountTransferred(msg.sender, customers[i], bookings[customers[i]].getValue(), "Flight Cancel Refund");
            } else if(bookings[customers[i]].getBookingData().state == BookingContract.BookingState.CANCELLED) {
                uint refund = bookings[customers[i]].getBookingData().cancelPenalty;
                payable(customers[i]).transfer(refund*10**18);
                bookings[customers[i]].flightCancelled();
                emit AmountTransferred(msg.sender, customers[i], refund, "Flight Cancel Refund");
            }
        }
    }

    function updateFlightStatus(string memory _flightNumber, Flight.FlightState _state, uint _delayInHours)
		public
        
		onlyAirlines{
            Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);
            require(bytes(flightData.flightNumber).length > 0, "Invalid flight number");
            require(_state != Flight.FlightState.CANCELLED, "Use cancelFlight api");
            require (block.timestamp > flightData.flightTime - 24 hours, "Updates permitted 24 hrs before flight departure time");
            if(_state == Flight.FlightState.DELAYED){
                require(_delayInHours > 0, "Update the delayed hours when the flight status is delayed");
            }
            flight.setFlightState(_flightNumber, _state, _delayInHours);
            flightStateUpdated = true;
            //on status set to departed passback customer locked money with contract
            if(_state == Flight.FlightState.DEPARTED) {
                _refundPendingAmountToCustomer(flightData.ethAmount);
            }
    }

    //Get Flight Information
    function getFlightData(string memory _flightNumber) public view returns (Flight.FlightData memory){
        Flight.FlightData memory flightData = flight.getFlightData(_flightNumber);
        require(bytes(flightData.flightNumber).length > 0, "Invalid flight number");
        return flight.getFlightData(_flightNumber);
    }

    function _refundPendingAmountToCustomer(uint _bookingAmount) private {
        for(uint i = 0; i < customers.length; i++) {
            if (bookings[customers[i]].getBookingData().state == BookingContract.BookingState.CONFIRMED) {
                uint lockedAmt = bookings[customers[i]].getValue() - _bookingAmount*10**18;
                payable(customers[i]).transfer(lockedAmt);
                emit AmountTransferred(address(this), customers[i], lockedAmt, "Customer pending amount refund");
            }
        }
    }
}