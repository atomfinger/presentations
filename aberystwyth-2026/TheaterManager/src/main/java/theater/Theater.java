package theater;

import java.util.List;

/**
 * Assignment: Theater Reservation System
 *
 * You are given this interface as part of the assignment.
 * Your task is to provide a concrete implementation of it.
 *
 * The goal of this assignment is to implement the core reservation
 * logic of a theater system. You should focus purely on domain logic.
 *
 * You are also given a Seat class, which represents a specific seat
 * in the theater. You may NOT modify the Seat class.
 *
 * A seat can be in one of two states:
 * - Available
 * - Reserved
 * <p>
 * Your implementation should enforce the following rules:
 *
 * - A seat that has not been reserved is considered available
 * - Reserving an available seat succeeds
 * - Reserving a seat that is already reserved fails
 * - Cancelling a reservation makes the seat available again
 * - Cancelling a seat that is not reserved fails
 *
 * Seat positions outside the bounds of the theater should be handled
 * gracefully (you must decide how, and document your choice).
 *
 * You are encouraged to think carefully about:
 * - How seat availability is tracked
 * - How invalid input is handled
 * - How your design supports future extensions
 *
 * This interface defines the required behavior but does not prescribe
 * how it should be implemented.
 */
public interface Theater {

    /**
     * Attempts to temporarily hold a number of consecutive seats in a single row.
     *
     * @param count the number of seats to hold
     * @param holdDurationMillis how long the hold should last in milliseconds
     * @return a list of held seats if successful, or an empty list if
     *         no suitable consecutive seats are available
     */
    List<Seat> holdConsecutiveSeats(int count, long holdDurationMillis);

    /**
     * Attempts to reserve a list of seats.
     *
     * Seats that are HELD by this customer or AVAILABLE can be reserved.
     * Seats that are HELD by someone else or RESERVED will not be reserved.
     *
     * @param seats the seats to reserve
     * @return true if the seats were reserved, otherwise false
     */
    Boolean reserve(List<Seat> seats);

    /**
     * Cancels a reservation or hold, making the seats AVAILABLE again.
     *
     * @param seats the seats to release
     */
    void release(List<Seat> seats);
}
