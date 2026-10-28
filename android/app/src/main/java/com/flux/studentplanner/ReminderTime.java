package com.flux.studentplanner;

import java.time.LocalDate;
import java.time.ZoneId;

/** Device-local civil deadline, converted to an instant only when scheduling. */
public final class ReminderTime {
    private ReminderTime() {}
    public static long triggerMillis(String date, int minute, String zone) {
        if (minute < 0 || minute >= 1440) throw new IllegalArgumentException("Invalid time");
        return LocalDate.parse(date).atTime(minute / 60, minute % 60)
                .atZone(ZoneId.of(zone)).minusMinutes(30).toInstant().toEpochMilli();
    }
}
