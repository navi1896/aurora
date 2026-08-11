extends SceneTree

const SERVICE = preload("res://src/online/OnlineManifestService.gd")

var failures := 0


func _init() -> void:
	_test_empty_catalog()
	_test_valid_catalog_entry()
	_test_untrusted_package_rejected()
	_test_latest_release()
	_test_version_comparison()
	if failures == 0:
		print("ONLINE MANIFEST TESTS PASSED")
		quit(0)
	else:
		push_error("ONLINE MANIFEST TESTS FAILED: %d" % failures)
		quit(1)


func _test_empty_catalog() -> void:
	var result := SERVICE.parse_catalog_bytes(JSON.stringify({
		"type": SERVICE.CATALOG_TYPE,
		"format_version": SERVICE.CATALOG_FORMAT_VERSION,
		"updated_at": "2026-08-07T00:00:00Z",
		"packages": [],
	}).to_utf8_buffer())
	_expect(bool(result.get("ok", false)), "empty catalog is valid")
	_expect((result.get("entries", []) as Array).is_empty(), "empty catalog has no entries")


func _test_valid_catalog_entry() -> void:
	var result := SERVICE.parse_catalog_bytes(JSON.stringify({
		"type": SERVICE.CATALOG_TYPE,
		"format_version": SERVICE.CATALOG_FORMAT_VERSION,
		"packages": [_valid_entry()],
	}).to_utf8_buffer())
	_expect(bool(result.get("ok", false)), "valid catalog entry is accepted")
	_expect((result.get("entries", []) as Array).size() == 1, "valid entry is returned")


func _test_untrusted_package_rejected() -> void:
	var entry := _valid_entry()
	entry["download_url"] = "https://example.com/song.aurora"
	var result := SERVICE.validate_catalog_entry(entry)
	_expect(not bool(result.get("ok", false)), "third-party package host is rejected")


func _test_latest_release() -> void:
	var release := {
		"tag_name": "v1.1.0",
		"name": "Aurora v1.1.0",
		"body": "Test release",
		"draft": false,
		"prerelease": false,
		"html_url": "https://github.com/navi1896/aurora/releases/tag/v1.1.0",
		"assets": [{
			"name": "Aurora-v1.1.0-Windows.zip",
			"browser_download_url": "https://github.com/navi1896/aurora/releases/download/v1.1.0/Aurora-v1.1.0-Windows.zip",
			"size": 1024,
			"digest": "sha256:%s" % "a".repeat(64),
		}],
	}
	var result := SERVICE.parse_latest_release_bytes(
		JSON.stringify(release).to_utf8_buffer(),
		"1.0.0"
	)
	_expect(bool(result.get("ok", false)), "latest release parses")
	_expect(bool(result.get("update_available", false)), "newer release is detected")
	_expect(bool(result.get("download_available", false)), "verified Windows asset is accepted")


func _test_version_comparison() -> void:
	_expect(SERVICE.compare_versions("1.2.0", "1.1.9") > 0, "minor version compares")
	_expect(SERVICE.compare_versions("1.0.0", "1.0.0") == 0, "equal version compares")
	_expect(SERVICE.compare_versions("0.9.9", "1.0.0") < 0, "older version compares")


func _valid_entry() -> Dictionary:
	return {
		"package_id": "test-song",
		"package_version": "1.0.0",
		"title": "Test Song",
		"artist": "Test Artist",
		"author": "Chart Author",
		"download_url": "https://github.com/navi1896/aurora/releases/download/songs/test-song.aurora",
		"sha256": "b".repeat(64),
		"size_bytes": 2048,
	}


func _expect(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
	else:
		failures += 1
		push_error("FAIL: %s" % label)
