'use strict';

const fs = require('fs');

const BLOCK_SIZE = 512;
const MAGIC_OFF = 257;
const MAGIC_LEN = 6;
const VER_OFF = 263;
const VER_LEN = 2;
const CHKSUM_OFF = 148;
const CHKSUM_LEN = 8;

function stderr(message) {
	fs.stderr.write(message);
}

function splice_bytes(data, offset, length, replacement) {
	return substr(data, 0, offset) + replacement + substr(data, offset + length);
}

function block_is_zero(block) {
	for (let i = 0; i < BLOCK_SIZE; i++)
		if (ord(substr(block, i, 1)) != 0)
			return false;

	return true;
}

function strip_nul_tail(value) {
	let end = length(value);

	while (end > 0 && ord(substr(value, end - 1, 1)) == 0)
		end--;

	return substr(value, 0, end);
}

function compute_checksum(header) {
	let sum = 0;

	for (let i = 0; i < BLOCK_SIZE; i++) {
		if (i >= CHKSUM_OFF && i < CHKSUM_OFF + CHKSUM_LEN)
			sum += 32;
		else
			sum += ord(substr(header, i, 1));
	}

	return sum;
}

function write_checksum(header, sum) {
	return splice_bytes(header, CHKSUM_OFF, CHKSUM_LEN, sprintf('%06o', sum) + chr(0) + ' ');
}

function parse_size(field) {
	let end = length(field);

	while (end > 0) {
		let byte = ord(substr(field, end - 1, 1));

		if (byte != 0 && byte != 9 && byte != 10 && byte != 11 && byte != 12 && byte != 13 && byte != 32)
			break;
		end--;
	}

	let out = substr(field, 0, end);

	return out ? (int(out, 8) || 0) : 0;
}

function patch_tar_file(fname) {
	print('patch file: ' + fname + '\n');

	let stat = fs.stat(fname);

	if (!stat) {
		stderr('Error: cannot stat ' + fname + '\n');
		return 0;
	}

	if (stat.size < BLOCK_SIZE) {
		stderr(sprintf('Error: file too small (<%d bytes): %s\n', BLOCK_SIZE, fname));
		return 0;
	}

	let file = fs.open(fname, 'r+');

	if (!file) {
		stderr('Error: cannot open ' + fname + '\n');
		return 0;
	}

	let zero_blocks = 0;
	let block_index = 0;

	while (block_index * BLOCK_SIZE < stat.size) {
		let pos = block_index * BLOCK_SIZE;

		file.seek(pos);
		let block = file.read(BLOCK_SIZE);

		if (!block || length(block) < BLOCK_SIZE)
			break;

		if (block_is_zero(block)) {
			zero_blocks++;
			block_index++;

			if (zero_blocks >= 2)
				break;

			continue;
		}

		zero_blocks = 0;

		let name = strip_nul_tail(substr(block, 0, 100));
		let magic = substr(block, MAGIC_OFF, MAGIC_LEN);
		let need_patch = (substr(magic, 0, 5) != 'ustar' &&
			magic == chr(0) + chr(0) + chr(0) + chr(0) + chr(0) + chr(0) &&
			length(name) > 0);

		if (need_patch) {
			let header = block;

			header = splice_bytes(header, MAGIC_OFF, MAGIC_LEN, 'ustar' + chr(0));
			header = splice_bytes(header, VER_OFF, VER_LEN, '00');
			header = write_checksum(header, compute_checksum(header));

			file.seek(pos);
			file.write(header);
			print(sprintf('patched header at block %d (offset %d)\n', block_index, pos));
		}

		let size = parse_size(substr(block, 124, 12));
		let data_blocks = int((size + BLOCK_SIZE - 1) / BLOCK_SIZE);

		block_index += 1 + data_blocks;
	}

	file.close();
	print('finished scanning ' + fname + '\n');

	return 0;
}

if (length(ARGV) < 1) {
	stderr('Usage: ucode ' + (ARGV[0] || 'patch.uc') + ' <tar-file>\n');
	exit(1);
}

exit(patch_tar_file(ARGV[0]));
