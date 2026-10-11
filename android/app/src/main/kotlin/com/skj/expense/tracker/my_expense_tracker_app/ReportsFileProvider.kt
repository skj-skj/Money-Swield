package com.skj.expense.tracker.my_expense_tracker_app

import androidx.core.content.FileProvider

/**
 * Shares a report from `cache/reports/` (phase-8.md §6.6). Its own
 * subclass so a second `<provider>` can be declared next to the photos'
 * one (one class can't back two providers); it shares nothing but
 * `res/xml/report_paths.xml`'s folder.
 */
class ReportsFileProvider : FileProvider()
