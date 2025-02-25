#!/usr/bin/env python3
"""
Twitch NFO Generator - Create NFO files for Twitch recordings for Plex/tinyMediaManager.
This script scans Twitch recording directories and generates NFO files compatible with
XBMCnfoMoviesImporter plugin.
"""

import os
import json
import xml.etree.ElementTree as ET
import xml.dom.minidom as minidom
from datetime import datetime
import argparse
import logging
import sys
from typing import Dict, List, Optional, Tuple, Set, Any


class TwitchNFOGenerator:
    """Class to generate NFO files for Twitch recordings."""

    def __init__(self, debug: bool = False):
        """Initialize the generator with debug mode option."""
        self.debug = debug

    def find_info_files(self, root_dir: str) -> List[str]:
        """Find all Twitch info JSON files recursively in the given directory.

        Args:
            root_dir: Root directory to search for info files

        Returns:
            List of paths to JSON info files
        """
        info_files = []
        for root, _, files in os.walk(root_dir):
            for file in files:
                if file.endswith("-info.json"):
                    info_files.append(os.path.join(root, file))
        return info_files

    def find_thumbnail_file(self, json_file_path: str) -> Optional[str]:
        """Find the thumbnail file in the same directory as the JSON file.

        Args:
            json_file_path: Path to the JSON info file

        Returns:
            Path to the thumbnail file or None if not found
        """
        directory = os.path.dirname(json_file_path)
        file_id = os.path.basename(json_file_path).split('-info.json')[0]

        # Check for standard thumbnail files
        possible_thumbnails = [
            f"{file_id}-thumbnail.jpg",
            f"{file_id}-web_thumbnail.jpg",
            f"{file_id}-video-poster.jpg"
        ]

        for thumbnail in possible_thumbnails:
            thumbnail_path = os.path.join(directory, thumbnail)
            if os.path.exists(thumbnail_path):
                return thumbnail_path

        # Check for sprite thumbnails
        sprites_dir = os.path.join(directory, "sprites")
        if os.path.exists(sprites_dir):
            sprite_files = [f for f in os.listdir(sprites_dir) if f.endswith('.jpg')]
            if sprite_files:
                sprite_files.sort()
                return os.path.join(sprites_dir, sprite_files[0])

        return None

    def load_json_data(self, json_file_path: str) -> Dict[str, Any]:
        """Load and parse the JSON data file.

        Args:
            json_file_path: Path to the JSON info file

        Returns:
            Dictionary containing JSON data
        """
        try:
            with open(json_file_path, 'r', encoding='utf-8') as f:
                json_data = json.load(f)
                if self.debug:
                    logging.debug(f"Full JSON data: {json.dumps(json_data, indent=2)}")
                return json_data
        except UnicodeDecodeError:
            with open(json_file_path, 'r', encoding='latin-1') as f:
                json_data = json.load(f)
                if self.debug:
                    logging.debug(f"Full JSON data: {json.dumps(json_data, indent=2)}")
                return json_data

    def extract_date(self, json_data: Dict[str, Any], json_file_path: str) -> Tuple[str, str]:
        """Extract the premiere date and year from the JSON data or file path.

        Args:
            json_data: Dictionary containing JSON data
            json_file_path: Path to the JSON info file

        Returns:
            Tuple of (premiere_date, year)
        """
        premiere_date = ''
        year = ''

        # Try to extract date from JSON fields
        date_fields_to_check = ['created_at', 'published_at', 'recorded_at']
        for date_field in date_fields_to_check:
            if date_field in json_data and json_data[date_field]:
                try:
                    created_date = datetime.strptime(json_data[date_field], '%Y-%m-%dT%H:%M:%SZ')
                    premiere_date = created_date.strftime('%Y-%m-%d')
                    year = str(created_date.year)

                    return premiere_date, year
                except ValueError:
                    logging.warning(f"Error parsing date from {date_field}: {json_data[date_field]}")

        # Try to extract date from file path
        path_parts = os.path.dirname(json_file_path).split('/')
        for part in path_parts:
            if part.startswith('20') and len(part) >= 10:  # 20XX-XX-XX...
                try:
                    date_part = part[:10]
                    created_date = datetime.strptime(date_part, '%Y-%m-%d')
                    premiere_date = date_part
                    year = str(created_date.year)
                    logging.info(f"Extracted date from path: {premiere_date}")
                    return premiere_date, year
                except ValueError:
                    pass

        # Try to extract date from directory name
        dir_name = os.path.basename(os.path.dirname(json_file_path))
        if dir_name.startswith('20') and len(dir_name) >= 10:
            try:
                date_part = dir_name[:10]
                created_date = datetime.strptime(date_part, '%Y-%m-%d')
                premiere_date = date_part
                year = str(created_date.year)
                logging.info(f"Extracted date from directory name: {premiere_date}")
                return premiere_date, year
            except ValueError:
                pass

        return premiere_date, year

    def extract_duration(self, json_data: Dict[str, Any]) -> int:
        """Extract the duration in seconds from the JSON data.

        Args:
            json_data: Dictionary containing JSON data

        Returns:
            Duration in seconds
        """
        duration_seconds = 0
        if 'duration' in json_data:
            try:
                duration_value = json_data['duration']
                if isinstance(duration_value, str) and duration_value.isdigit():
                    duration_seconds = int(duration_value)
                elif isinstance(duration_value, int):
                    duration_seconds = duration_value
                elif isinstance(duration_value, str) and 'T' in duration_value:
                    # ISO format with T
                    duration_parts = duration_value.split('T')[1].split(':')
                    hours = int(duration_parts[0])
                    minutes = int(duration_parts[1])
                    seconds = int(float(duration_parts[2]))
                    duration_seconds = hours * 3600 + minutes * 60 + seconds
                else:
                    # Check for nanoseconds (divide by 1_000_000_000)
                    try:
                        duration_seconds = int(float(duration_value) / 1_000_000_000)
                    except (ValueError, TypeError):
                        pass

                logging.debug(f"Extracted duration: {duration_seconds} seconds")
            except Exception as e:
                logging.error(f"Error parsing duration: {json_data.get('duration', 'N/A')}, error: {str(e)}")

        return duration_seconds

    def format_chapter_description(self, json_data: Dict[str, Any]) -> str:
        """Format the chapter description for the NFO file.

        Args:
            json_data: Dictionary containing JSON data

        Returns:
            Chapter description string
        """
        chapter_description = ''
        if 'chapters' in json_data and json_data['chapters']:
            chapter_description = "\n\nChapters:\n"
            for chapter_data in json_data['chapters']:
                start_time_seconds = int(chapter_data.get('start', 0))
                hours = start_time_seconds // 3600
                minutes = (start_time_seconds % 3600) // 60
                seconds = start_time_seconds % 60
                time_formatted = f"{hours:02d}:{minutes:02d}:{seconds:02d}"

                chapter_description += f"{time_formatted} - {chapter_data.get('title', 'Untitled Chapter')}\n"

        return chapter_description

    def extract_unique_games(self, json_data: Dict[str, Any]) -> Set[str]:
        """Extract unique game names from chapters.

        Args:
            json_data: Dictionary containing JSON data

        Returns:
            Set of unique game names
        """
        games = set()
        if 'chapters' in json_data and json_data['chapters']:
            for chapter in json_data['chapters']:
                if 'title' in chapter and chapter['title']:
                    games.add(chapter['title'])

        return games

    def create_nfo_file(self, json_file_path: str, dry_run: bool = False, force: bool = False) -> bool:
        """Create an NFO file in XML format with the extracted metadata.

        Args:
            json_file_path: Path to the JSON info file
            dry_run: If True, don't actually write the file
            force: If True, overwrite existing NFO files

        Returns:
            True if the file was created, False otherwise
        """
        # Extract the video filename from the JSON filename pattern
        video_id = os.path.basename(json_file_path).split('-info.json')[0]
        video_filename = f"{video_id}-video.mp4"
        output_path = os.path.join(os.path.dirname(json_file_path), f"{video_id}-video.nfo")

        # Check if the NFO file already exists
        if os.path.exists(output_path) and not force:
            logging.info(f"NFO file already exists: {output_path}. Use --force to overwrite.")
            return False

        # Load JSON data
        json_data = self.load_json_data(json_file_path)

        # Extract basic metadata
        title = json_data.get('title', 'Unknown Title')
        user_name = json_data.get('user_name', 'Unknown User')
        description = json_data.get('description', '')
        language = json_data.get('language', '')

        # Extract date information
        premiere_date, year = self.extract_date(json_data, json_file_path)

        # Extract duration
        duration_seconds = self.extract_duration(json_data)

        # Create XML structure
        movie = ET.Element('movie')

        # Add basic metadata
        ET.SubElement(movie, 'title').text = title

        # Add original title as "Streamer - Date - Title"
        streamer_date = f"{user_name} - {premiere_date} - {title}"
        ET.SubElement(movie, 'originaltitle').text = streamer_date

        # Add sort title by date
        ET.SubElement(movie, 'sorttitle').text = f"{premiere_date} - {title}"

        ET.SubElement(movie, 'epbookmark')
        ET.SubElement(movie, 'year').text = year

        # Add ratings
        ratings = ET.SubElement(movie, 'ratings')
        ET.SubElement(movie, 'userrating').text = '0'
        ET.SubElement(movie, 'top250').text = '0'

        # Add set for grouping by streamer
        ET.SubElement(movie, 'set').text = user_name

        # Format description with chapter timecodes
        chapter_description = self.format_chapter_description(json_data)
        full_description = description + chapter_description if description else chapter_description
        ET.SubElement(movie, 'plot').text = full_description

        ET.SubElement(movie, 'tagline')
        ET.SubElement(movie, 'runtime').text = str(duration_seconds)
        ET.SubElement(movie, 'mpaa')
        ET.SubElement(movie, 'certification')
        ET.SubElement(movie, 'id')
        ET.SubElement(movie, 'tmdbid')
        ET.SubElement(movie, 'status')
        ET.SubElement(movie, 'code')

        # Add premiere and aired dates
        premiere_elem = ET.SubElement(movie, 'premiered')
        premiere_elem.text = premiere_date

        aired_elem = ET.SubElement(movie, 'aired')
        aired_elem.text = premiere_date

        ET.SubElement(movie, 'watched').text = 'false'
        ET.SubElement(movie, 'playcount').text = '0'
        ET.SubElement(movie, 'studio').text = user_name
        ET.SubElement(movie, 'trailer')

        # Add genres based on chapters
        games = self.extract_unique_games(json_data)
        for game in games:
            genre = ET.SubElement(movie, 'genre')
            genre.text = game

        # Add main category as genre
        if 'category' in json_data and json_data['category']:
            main_genre = ET.SubElement(movie, 'genre')
            main_genre.text = json_data['category']

        # Add tags for categories and channel
        for game in games:
            game_tag = ET.SubElement(movie, 'tag')
            game_tag.text = game

        # Add main category as tag
        if 'category' in json_data and json_data['category']:
            category_tag = ET.SubElement(movie, 'tag')
            category_tag.text = json_data['category']

        # Add streamer as tag
        channel_tag = ET.SubElement(movie, 'tag')
        channel_tag.text = user_name

        # Add languages
        languages = ET.SubElement(movie, 'languages')
        if language:
            ET.SubElement(languages, 'language').text = language

        # Add thumbnail
        thumbnail_path = self.find_thumbnail_file(json_file_path)
        if thumbnail_path:
            # Make path relative
            nfo_dir = os.path.dirname(json_file_path)
            if thumbnail_path.startswith(nfo_dir):
                thumbnail_path = os.path.relpath(thumbnail_path, nfo_dir)

            # Add thumb element
            ET.SubElement(movie, 'thumb').text = thumbnail_path

        # Add date added
        ET.SubElement(movie, 'dateadded').text = datetime.now().strftime('%Y-%m-%d %H:%M:%S')

        # Add chapters
        if 'chapters' in json_data and json_data['chapters']:
            chapters = ET.SubElement(movie, 'chapters')
            for chapter_data in json_data['chapters']:
                # Convert start time to seconds
                start_time_seconds = int(chapter_data.get('start', 0))

                # Create chapter element with attributes
                chapter = ET.SubElement(chapters, 'chapter', {
                    'name': chapter_data.get('title', 'Untitled Chapter'),
                    'start': str(start_time_seconds)
                })

        # Add file info
        fileinfo = ET.SubElement(movie, 'fileinfo')
        streamdetails = ET.SubElement(fileinfo, 'streamdetails')

        # Add video details
        video = ET.SubElement(streamdetails, 'video')
        ET.SubElement(video, 'codec').text = 'h264'
        ET.SubElement(video, 'aspect').text = '1.78'
        ET.SubElement(video, 'width').text = '1920'
        ET.SubElement(video, 'height').text = '1080'
        ET.SubElement(video, 'durationinseconds').text = str(duration_seconds)
        ET.SubElement(video, 'stereomode')

        # Add audio details
        audio = ET.SubElement(streamdetails, 'audio')
        ET.SubElement(audio, 'codec').text = 'AAC'
        ET.SubElement(audio, 'language')
        ET.SubElement(audio, 'channels').text = '1'

        # Add tinyMediaManager metadata
        comment = ET.Comment('tinyMediaManager meta data')
        movie.append(comment)

        ET.SubElement(movie, 'source').text = 'UNKNOWN'
        ET.SubElement(movie, 'edition').text = 'NONE'
        ET.SubElement(movie, 'original_filename').text = video_filename
        ET.SubElement(movie, 'user_note')

        # Debug checks for dates
        if self.debug:
            self.debug_xml_dates(movie, premiere_elem, aired_elem, premiere_date)

        # Convert to pretty-printed XML
        rough_string = ET.tostring(movie, 'utf-8')
        reparsed = minidom.parseString(rough_string)

        # Add XML declaration and comment
        xml_declaration = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        tmm_comment = f'<!--created on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")} by tinyMediaManager 5.1 for PLEX-->\n'
        pretty_xml = xml_declaration + tmm_comment + reparsed.toprettyxml(indent="  ")[23:]

        # Final debug check for XML
        if self.debug:
            self.debug_final_xml(pretty_xml, premiere_date)

        # Write to file
        if dry_run:
            logging.info(f"Would create NFO file: {output_path}")
        else:
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(pretty_xml)
            logging.info(f"Created NFO file: {output_path}")

        return True

    def debug_xml_dates(self, movie: ET.Element, premiere_elem: ET.Element, aired_elem: ET.Element, premiere_date: str) -> None:
        """Debug XML date elements.

        Args:
            movie: XML movie element
            premiere_elem: premiered element
            aired_elem: aired element
            premiere_date: premiere date string
        """
        xml_string = ET.tostring(movie, 'utf-8')
        logging.debug(f"Checking XML elements for dates:")
        logging.debug(f"premiered: {premiere_elem.text}")
        logging.debug(f"aired: {aired_elem.text}")

        if b'<premiered>' in xml_string:
            logging.debug("Found <premiered> tag in raw XML")
        else:
            logging.debug("NO <premiered> tag in raw XML")

        if premiere_date:
            logging.debug(f"premiere_date variable: '{premiere_date}'")
            if premiere_date.encode('utf-8') in xml_string:
                logging.debug("Found premiere_date value in raw XML")
            else:
                logging.debug("NO premiere_date value in raw XML")

    def debug_final_xml(self, pretty_xml: str, premiere_date: str) -> None:
        """Debug final XML output.

        Args:
            pretty_xml: XML string
            premiere_date: premiere date string
        """
        if '<premiered>' in pretty_xml and premiere_date and premiere_date in pretty_xml:
            logging.debug("FINAL XML contains correct premiered tag and value")
        else:
            logging.debug(f"PROBLEM in FINAL XML with premiered tag!")
            logging.debug(f"premiered tag exists: {'<premiered>' in pretty_xml}")
            logging.debug(f"premiere_date value: '{premiere_date}'")
            logging.debug(f"premiere_date in XML: {premiere_date in pretty_xml}")

    def process_files(self, root_dir: str, dry_run: bool = False, force: bool = False) -> Tuple[int, int, int]:
        """Process all Twitch info files in the given directory structure.

        Args:
            root_dir: Root directory to search for info files
            dry_run: If True, don't actually write the files
            force: If True, overwrite existing NFO files

        Returns:
            Tuple of (processed_count, skipped_count, error_count)
        """
        info_files = self.find_info_files(root_dir)
        logging.info(f"Found {len(info_files)} info files to process.")

        processed_count = 0
        skipped_count = 0
        error_count = 0

        for info_file in info_files:
            try:
                if self.create_nfo_file(info_file, dry_run, force):
                    processed_count += 1
                else:
                    skipped_count += 1
            except Exception as e:
                logging.error(f"Error processing {info_file}: {str(e)}")
                error_count += 1

        return processed_count, skipped_count, error_count


def setup_logging(verbose: bool = False) -> None:
    """Set up logging configuration.

    Args:
        verbose: If True, set log level to DEBUG
    """
    log_level = logging.DEBUG if verbose else logging.INFO
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )


def main() -> int:
    """Main function to run the script.

    Returns:
        Exit code (0 for success, 1 for error)
    """
    parser = argparse.ArgumentParser(description='Create NFO files for Twitch recordings based on JSON metadata.')
    parser.add_argument('root_dir', nargs='?', help='Root directory of Twitch recordings')
    parser.add_argument('--dry-run', action='store_true', help='Show what would be done without actually writing files')
    parser.add_argument('--verbose', '-v', action='store_true', help='Enable verbose logging')
    parser.add_argument('--force', '-f', action='store_true', help='Overwrite existing NFO files')
    parser.add_argument('--debug', '-d', action='store_true', help='Enable extra debug logging')

    args = parser.parse_args()

    # Set up logging
    setup_logging(args.verbose or args.debug)

    # Get the root directory
    root_dir = args.root_dir
    if not root_dir:
        root_dir = input("Enter the root directory of your Twitch recordings: ")

    if not os.path.isdir(root_dir):
        logging.error(f"Error: {root_dir} is not a valid directory.")
        return 1

    try:
        generator = TwitchNFOGenerator(debug=args.debug)
        processed, skipped, errors = generator.process_files(root_dir, args.dry_run, args.force)

        logging.info(f"Processing summary: {processed} created, {skipped} skipped, {errors} errors, out of {processed + skipped + errors} total files.")
        logging.info("Processing complete!")
        return 0
    except Exception as e:
        logging.error(f"An error occurred: {str(e)}")
        return 1


if __name__ == "__main__":
    sys.exit(main())