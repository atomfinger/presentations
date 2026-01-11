package theater;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class TheaterImpl implements Theater {


    @Override
    public List<Seat> holdConsecutiveSeats(int count, long holdDurationMillis) {
        return List.of();
    }

    @Override
    public Boolean reserve(List<Seat> seats) {
        return false;
    }

    @Override
    public void release(List<Seat> seats) {

    }
}
