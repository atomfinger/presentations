package theater;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class TheaterImplTest {

    TheaterImpl theater;

    @BeforeEach
    void setUp() {
        theater = new TheaterImpl();
    }
}