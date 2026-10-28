import com.flux.studentplanner.ReminderTime;
import java.time.Instant;

/** Runs without Android; assertions verify the exact same time code used by alarms. */
public final class ReminderTimeTest {
    private static int checks;
    private static void expect(String date, int minute, String zone, String instant) {
        long actual = ReminderTime.triggerMillis(date, minute, zone);
        if (actual != Instant.parse(instant).toEpochMilli()) throw new AssertionError(date + " " + zone + ": " + Instant.ofEpochMilli(actual));
        checks++;
    }
    public static void main(String[] args) {
        // 2pm in India -> 1:30pm IST -> 08:00 UTC.
        expect("2026-10-29", 14 * 60, "Asia/Kolkata", "2026-10-29T08:00:00Z");
        expect("2026-10-29", 14 * 60, "America/New_York", "2026-10-29T17:30:00Z");
        // Same wall deadline after a timezone change, not the old fixed UTC instant.
        expect("2026-10-29", 14 * 60, "Europe/London", "2026-10-29T13:30:00Z");
        // The reminder belongs to the previous local day.
        expect("2026-10-29", 15, "Asia/Kolkata", "2026-10-28T18:15:00Z");
        // US spring daylight-saving gap: deadline 03:00 EDT, reminder 01:30 EST.
        expect("2026-03-08", 180, "America/New_York", "2026-03-08T06:30:00Z");
        // Repeated hour: Java chooses the earlier valid offset consistently.
        expect("2026-11-01", 90, "America/New_York", "2026-11-01T05:00:00Z");
        expect("2026-10-29", 14 * 60, "GMT+05:30", "2026-10-29T08:00:00Z");
        for (int bad : new int[]{-1, 1440}) {
            try { ReminderTime.triggerMillis("2026-10-29", bad, "UTC"); throw new AssertionError("Accepted invalid minute"); }
            catch (IllegalArgumentException expected) { checks++; }
        }
        System.out.println("PASS: " + checks + " native reminder timing checks.");
    }
}
