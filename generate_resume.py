import yaml
from pylatex import Document, Section, Subsection, Command, Package, MiniPage, LineBreak
from pylatex.utils import italic, bold, NoEscape
from pylatex.lists import Itemize
from pylatex.table import Tabular

# Helper function to sanitize text for LaTeX
def sanitize_latex_text(text):
    if not isinstance(text, str):
        text = str(text)
    # Replace special LaTeX characters
    # Note: Order can matter here if replacements generate other special characters.
    # However, for this set, it's generally fine.
    replacements = {
        "&": r"\&",
        "%": r"\%",
        "$": r"\$",
        "#": r"\#",
        "_": r"\_",
        "{": r"\{",
        "}": r"\}",
        "~": r"\textasciitilde{}",
        # '\\': r'\textbackslash{}', # Be careful with backslashes
        # '^': r'\textasciicircum{}'
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text

# Helper function to generate rating dots
def get_rating_dots(rating_value, total_dots=5):
    """Generates LaTeX string for skill rating dots using FontAwesome icons."""
    if not isinstance(rating_value, int) or not (0 <= rating_value <= total_dots):
        # Return empty string or some placeholder for invalid ratings
        return ""

    filled_dot_color = "themecolor"  # Main theme color for filled dots
    empty_dot_color = "lightgray" # Softer color for empty dots
    dot_size = r"\normalsize"      # Size of the dots, adjust as needed
    dot_spacing = r"\hspace{0.1em}" # Spacing between dots

    # Use aIcon[style]{name} from fontawesome5 package
    filled_dots_str = (r"{\color{" + filled_dot_color + r"} " + dot_size + r" \faIcon[solid]{circle}}" + dot_spacing) * rating_value
    empty_dots_str = (r"{\color{" + empty_dot_color + r"} " + dot_size + r" \faIcon[regular]{circle}}" + dot_spacing) * (total_dots - rating_value)
    
    return (filled_dots_str + empty_dots_str).strip() # .strip() to remove potential trailing hspace

def load_resume_data(yaml_file_path):
    """Loads resume data from a YAML file."""
    try:
        with open(yaml_file_path, 'r', encoding='utf-8') as file:
            data = yaml.safe_load(file)
        # print("Successfully loaded data from resume.yaml") # Removed this duplicate print
        return data
    except FileNotFoundError:
        print(f"Error: The file {yaml_file_path} was not found.")
        return None
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file {yaml_file_path}: {e}")
        return None

def add_contact_info(doc, contact):
    """Adds contact information to the document header."""
    if not contact:
        return

    with doc.create(MiniPage(width=r"\textwidth")):
        # Name - Centered, Large, Bold
        if contact.get('name'):
            doc.append(Command('centering'))
            doc.append(NoEscape(r"{\Huge\bfseries\color{themecolor} " + sanitize_latex_text(contact['name']) + r"}\par"))
            doc.append(NoEscape(r"\vspace{0.2em}")) # Small space after name

        # Contact details line
        contact_items_tex = []
        if contact.get('email'):
            contact_items_tex.append(NoEscape(r"\faEnvelope\enspace \href{mailto:" + contact['email'] + r"}{\color{darkgray}" + sanitize_latex_text(contact['email']) + r"}"))
        if contact.get('phone'):
            contact_items_tex.append(NoEscape(r"\faPhone\enspace {\color{darkgray}" + sanitize_latex_text(contact['phone']) + r"}"))
        if contact.get('location'):
            contact_items_tex.append(NoEscape(r"\faMapMarkerAlt\enspace {\color{darkgray}" + sanitize_latex_text(contact['location']) + r"}"))

        doc.append(Command('centering'))
        separator = NoEscape(r' ~|~ ')
        doc.append(NoEscape(separator.join(contact_items_tex) + r"\par"))
        doc.append(NoEscape(r"\vspace{0.1em}"))

        # Second line for web links if they exist
        web_links_tex = []
        if contact.get('linkedin'):
            linkedin_url = contact['linkedin']
            if not linkedin_url.startswith('http'):
                linkedin_url = f"https://linkedin.com/in/{linkedin_url}"
            web_links_tex.append(NoEscape(r"\faLinkedin\enspace \href{" + linkedin_url + r"}{\color{darkgray}" + sanitize_latex_text(contact['linkedin'].replace('https://linkedin.com/in/','')) + r"}"))
        if contact.get('github'):
            github_url = contact['github']
            if not github_url.startswith('http'):
                github_url = f"https://github.com/{github_url}"
            web_links_tex.append(NoEscape(r"\faGithub\enspace \href{" + github_url + r"}{\color{darkgray}" + sanitize_latex_text(contact['github'].replace('https://github.com/','')) + r"}"))
        if contact.get('website'):
            website_url = contact['website']
            if not website_url.startswith('http'):
                 website_url = f"https://{website_url}"
            web_links_tex.append(NoEscape(r"\faGlobe\enspace \href{" + website_url + r"}{\color{darkgray}" + sanitize_latex_text(contact['website'].replace('https://','')) + r"}"))

        if web_links_tex:
            doc.append(Command('centering'))
            doc.append(NoEscape(" \quad | \quad ".join(web_links_tex) + r"\par"))

        doc.append(NoEscape(r"\vspace{1em}")) # Space after contact block

def add_profile_section(doc, profile_text):
    """Adds the profile section to the document."""
    with doc.create(Section("Profile", numbering=False)):
        if isinstance(profile_text, list):
            # Process each item for internal newlines, then join paragraphs
            processed_items = [sanitize_latex_text(item).replace('\n', r'\newline ') for item in profile_text]
            processed_profile_text = r"\newline ".join(processed_items) # Use \newline for paragraph-like separation from list
        elif isinstance(profile_text, str):
            processed_profile_text = sanitize_latex_text(profile_text).replace('\n', r'\newline ')
        else:
            processed_profile_text = "Profile data is not in expected format (string or list)."
            print(f"Warning: Profile data type was {type(profile_text)}, expected str or list.")

        doc.append(NoEscape(processed_profile_text))

def add_experience_section(doc, experiences, section_title="Experience"):
    """Adds a section for professional experience (or similar chronological list)."""
    if not experiences:
        return

    with doc.create(Section(section_title, numbering=False)):
        for i, job in enumerate(experiences):
            doc.append(NoEscape(r"\Needspace{12\baselineskip}")) # Ensure space for the entry

            title = sanitize_latex_text(job.get('title', ''))
            company = sanitize_latex_text(job.get('company', ''))
            location = sanitize_latex_text(job.get('location', ''))
            start_date = sanitize_latex_text(job.get('start_date', ''))
            end_date = sanitize_latex_text(job.get('end_date') if job.get('end_date') else 'Present')

            # Job Title
            if title:
                doc.append(NoEscape(r"{\large\bfseries\color{themecolor} " + title + r"}\par"))
                doc.append(NoEscape(r"\vspace{0.05em}"))

            # Company | Location \hfill Start - End
            header_parts = []
            if company:
                header_parts.append(r"{\bfseries " + company + r"}")
            if location:
                header_parts.append(r"{\itshape " + location + r"}")

            date_string = r"{\small\itshape\color{mediumgray} " + start_date + " – " + end_date + r"}"

            if header_parts:
                doc.append(NoEscape(" \quad | \quad ".join(header_parts) + r" \hfill " + date_string + r"\par"))
            else: # Only dates if no company/location
                doc.append(NoEscape(r"\hfill " + date_string + r"\par"))

            # App Store / Media Links
            link_items_tex = []
            app_store_url_yaml = job.get('app_store_url')
            if app_store_url_yaml:
                link_items_tex.append(NoEscape(r"\mbox{\faApple\enspace \href{" + app_store_url_yaml + r"}{App Store}}"))

            media_urls_data = job.get('media_urls', [])
            if isinstance(media_urls_data, str):
                media_urls_data = [media_urls_data] # Coerce to list if it's a single string

            for m_url in media_urls_data:
                if app_store_url_yaml and app_store_url_yaml == m_url:
                    continue # Avoid duplicating the App Store link if also in media_urls

                try:
                    domain_parts = m_url.split('//')[-1].split('/')
                    domain = domain_parts[0].replace('www.', '')
                    link_text = domain
                    # Simple heuristic for common sites to make link text cleaner
                    if 'github.com' in domain: link_text = f"GitHub: {domain_parts[1] if len(domain_parts) > 1 else domain}"
                    elif 'techcrunch.com' in domain: link_text = "TechCrunch"
                    elif 'venturebeat.com' in domain: link_text = "VentureBeat"
                    # Add more specific overrides if needed based on typical URLs in resume
                except IndexError:
                    link_text = "Media Link"

                link_items_tex.append(NoEscape(r"\mbox{\faLink\enspace \href{" + m_url + r"}{ " + sanitize_latex_text(link_text) + r"}}"))

            if link_items_tex:
                doc.append(NoEscape(r"\vspace{0.25em}"))
                doc.append(NoEscape(r"{\small " + " \quad | \quad ".join(link_items_tex) + r"}\par"))

            # Responsibilities
            responsibilities = job.get('responsibilities', [])
            if responsibilities:
                doc.append(NoEscape(r"\vspace{0.3em}"))
                # Using PyLaTeX's Itemize directly
                with doc.create(Itemize(options=NoEscape(r"leftmargin=1.5em, label=\textbullet, nosep, topsep=0.2em, itemsep=0.15em"))) as itemize:
                    for resp_item in responsibilities:
                        if isinstance(resp_item, str):
                            itemize.add_item(NoEscape(sanitize_latex_text(resp_item).replace('\n', r'\newline '))) # Handle multi-line responsibilities
                        else:
                            print(f"Warning: Responsibility item in 'experience' section expected string, got {type(resp_item)}: {resp_item}. Skipping this item.")

            if i < len(experiences) - 1:
                 doc.append(NoEscape(r"\vspace{1em}")) # Space between job entries

def add_projects_section(doc, projects, section_title="Personal Projects"):
    """Adds a section for projects (e.g., Personal Projects, Open Source)."""
    if not projects:
        return

    with doc.create(Section(section_title, numbering=False)):
        for i, project in enumerate(projects):
            doc.append(NoEscape(r"\Needspace{8\baselineskip}")) # Adjust as needed

            name = sanitize_latex_text(project.get('name', ''))
            description = project.get('description', '') # Will be sanitized before use

            # Project Name
            if name:
                doc.append(NoEscape(r"{\large\bfseries\color{themecolor} " + name + r"}\par"))
                doc.append(NoEscape(r"\vspace{0.2em}"))

            # Description
            if description:
                doc.append(NoEscape(sanitize_latex_text(description).replace('\n', r'\newline ') + r"\par")) # Ensure YAML newlines are respected

            # Links (App Store and others)
            link_items_tex = []
            app_store_url_yaml = project.get('app_store_link') # Note: YAML key is app_store_link
            if app_store_url_yaml:
                link_items_tex.append(NoEscape(r"\mbox{\faApple\enspace \href{" + app_store_url_yaml + r"}{App Store}}"))

            other_links_data = project.get('links', [])
            if isinstance(other_links_data, str): # Should be a list of dicts
                other_links_data = []

            for link_item in other_links_data:
                link_title = sanitize_latex_text(link_item.get('title', 'Link'))
                link_url = link_item.get('url')
                if link_url:
                    # Avoid duplicating app store link if it's also in general links with same URL
                    if app_store_url_yaml and app_store_url_yaml == link_url and sanitize_latex_text(link_title).lower() == 'app store':
                        continue
                    link_items_tex.append(NoEscape(r"\mbox{\faLink\enspace \href{" + link_url + r"}{ " + link_title + r"}}"))

            if link_items_tex:
                doc.append(NoEscape(r"\vspace{0.25em}"))
                doc.append(NoEscape(r"{\small " + " \quad | \quad ".join(link_items_tex) + r"}\par"))

            if i < len(projects) - 1:
                 doc.append(NoEscape(r"\vspace{0.8em}")) # Space between project entries

def add_skills_section(doc, skills_data):
    """Adds a skills section to the document with a compact grid layout."""
    if not skills_data:
        return

    doc.append(Command('section', 'Skills'))
    doc.append(NoEscape(r"\vspace{-0.5em}")) # Reduce space after section title slightly

    level_map = {
        1: "Basic",
        2: "Familiar",
        3: "Proficient",
        4: "Advanced",
        5: "Expert"
    }

    # data['skills'] is a dictionary like:
    # { 'programming_languages': [ {'name': 'Swift', ...}, ... ],
    #   'sdks_apis': [ {'name': 'iOS SDK', ...}, ... ] }
    # So, we iterate through its items.
    organized_skills = {}
    for category_key, skill_list in skills_data.items():
        # Convert category_key (e.g., 'programming_languages') to a title (e.g., 'Programming Languages')
        category_title = sanitize_latex_text(category_key.replace('_', ' ').title())
        # Special handling for 'sdks_apis' to 'SDKs & APIs' for better display
        if category_key == "sdks_apis":
            category_title = "SDKs \\& APIs" # Escape the ampersand for LaTeX

        organized_skills[category_title] = []
        for skill_item in skill_list:
            skill_name = sanitize_latex_text(skill_item.get('name', ''))
            rating = skill_item.get('rating')
            organized_skills[category_title].append((skill_name, rating))

    doc.append(NoEscape(r"\vspace{0.2em}")) # Small space after category title

    # Determine the order of categories to display. 
    # You might want a predefined order if alphabetical doesn't suit.
    # For now, using sorted keys of organized_skills for consistent ordering.
    category_order = sorted(organized_skills.keys())

    table_content_tex = []
    first_category_processed = False
    for category_title in category_order:
        skills_list_for_category = organized_skills[category_title]
        if not skills_list_for_category: 
            continue

        # Add vertical space before new category header, if not the very first one.
        if first_category_processed:
            table_content_tex.append(NoEscape(r"\noalign{\vspace{0.6em}}"))
        
        # Category title as a multi-column row in the table, left-aligned.
        table_content_tex.append(NoEscape(r"\multicolumn{2}{@{}l@{}}{\textbf{" + sanitize_latex_text(category_title) + r"}} \\ "))
        # Add a little space after category title, before skills for that category.
        table_content_tex.append(NoEscape(r"\noalign{\vspace{0.2em}}"))

        for skill_name, rating in skills_list_for_category:
            if not skill_name: 
                continue
            rating_dots = get_rating_dots(rating) # Assuming get_rating_dots is defined elsewhere
            table_content_tex.append(f"{sanitize_latex_text(skill_name)} & {rating_dots} \\")
        
        first_category_processed = True # Mark that at least one category has been processed

    if table_content_tex:
        doc.append(NoEscape(r"\begin{tabular}{@{}>{\RaggedRight}p{3.5cm}@{}>{\RaggedLeft}p{3cm}@{}}"))
        doc.append(NoEscape("\n".join(table_content_tex)))
        doc.append(NoEscape(r"\end{tabular}"))

def add_education_section(doc, education_data):
    """Adds an education section to the document."""
    if not education_data:
        return

    with doc.create(Section("Education", numbering=False)):
        for i, edu_item in enumerate(education_data):
            doc.append(NoEscape(r"\Needspace{6\baselineskip}")) # Ensure space for the entry

            institution = sanitize_latex_text(edu_item.get('institution', ''))
            degree = sanitize_latex_text(edu_item.get('degree', ''))
            major = sanitize_latex_text(edu_item.get('major')) # This can be None
            grad_date = sanitize_latex_text(edu_item.get('graduation_date', ''))

            # Institution Name
            if institution:
                doc.append(NoEscape(r"{\large\bfseries\color{themecolor} " + institution + r"}\par"))
                doc.append(NoEscape(r"\vspace{0.1em}"))

            # Degree, Major and Date line
            degree_major_parts = []
            if degree:
                degree_major_parts.append(r"{\bfseries " + degree + r"}")
            if major: # Only add major if it exists and is not empty
                degree_major_parts.append(major)

            degree_major_str = ", ".join(degree_major_parts)

            date_str = ""
            if grad_date:
                date_str = r"{\small\itshape\color{mediumgray} " + grad_date + r"}"

            if degree_major_str and date_str:
                doc.append(NoEscape(degree_major_str + r" \hfill " + date_str + r"\par"))
            elif degree_major_str: # Only degree/major
                doc.append(NoEscape(degree_major_str + r"\par"))
            elif date_str: # Only date (less likely but handle)
                doc.append(NoEscape(r"\hfill " + date_str + r"\par"))

            # Add small space if there were details, before the larger inter-item space
            if degree_major_str or date_str:
                doc.append(NoEscape(r"\vspace{0.2em}"))

            if i < len(education_data) - 1:
                doc.append(NoEscape(r"\vspace{0.8em}")) # Space between education entries

def add_formatted_contributions_section(doc, contributions, section_title="Open Source Contributions"):
    """Adds a formatted section for open source contributions and personal projects."""
    if not contributions:
        return

    doc.append(NoEscape(r"\Needspace{10\baselineskip}")) # Ensure space for the section
    with doc.create(Section(section_title, numbering=False)):
        # Adjust itemize options for a slightly less compact feel if desired, or keep as is.
        doc.append(NoEscape(r"\begin{itemize}[leftmargin=*, itemsep=0.3em, topsep=0.3em, parsep=0.1em]"))

        for i, contrib_or_project in enumerate(contributions):
            name = sanitize_latex_text(contrib_or_project.get('name', ''))
            description = contrib_or_project.get('description', '')
            links_data = contrib_or_project.get('links', [])
            if isinstance(links_data, str): links_data = []
            app_store_url_yaml = contrib_or_project.get('app_store_link')

            item_tex = r"\item "
            if name:
                item_tex += r"{\bfseries " + name + r"} "
            
            if description:
                item_tex += NoEscape(r"-- " + sanitize_latex_text(description).split('\n')[0])

            link_parts = []
            # Handle App Store link first
            if app_store_url_yaml:
                link_parts.append(NoEscape(r"\href{" + app_store_url_yaml + r"}{\faApple\enspace App Store}"))

            # Handle other links
            for link_item in links_data:
                link_title = sanitize_latex_text(link_item.get('title', 'Link'))
                link_url = link_item.get('url')
                if link_url:
                    # Avoid duplicating app store link if it was already added and has same URL
                    if app_store_url_yaml and app_store_url_yaml == link_url and link_title.lower() == 'app store':
                        continue
                    icon = r"\faLink"
                    if "github" in link_url.lower():
                        icon = r"\faGithub"
                    link_parts.append(r"\href{" + link_url + r"}{" + icon + r" " + link_title + r"}")
            
            if link_parts:
                item_tex += NoEscape(r" {\small " + ", ".join(link_parts) + r"}")

            doc.append(NoEscape(item_tex))

        doc.append(NoEscape(r"\end{itemize}"))

def add_skills_section_updated(doc, skills_data):
    """Adds a combined skills section to the document, organized by category without proficiency subheadings."""
    if not skills_data:
        return

    organized_skills = {}
    # skills_data is now structured as: {category_yaml_key: [skill_items]}
    # e.g., {'programming_languages': [{'name': 'Python', 'rating': 5}], 'sdks_apis': [{...}]}
    for category_yaml_key, skills_list_for_category_from_yaml in skills_data.items():
        # Convert category_yaml_key to a display title
        display_category_title = category_yaml_key.replace('_', ' ').title()
        # Special case for 'sdks_apis' to ensure it's 'SDKs & APIs' before sanitization
        if category_yaml_key == "sdks_apis":
            display_category_title = "SDKs & APIs"
        
        # The display_category_title will be used as a key in organized_skills
        # and sanitized later when used as a header in LaTeX.
        if display_category_title not in organized_skills:
            organized_skills[display_category_title] = []
        
        # skills_list_for_category_from_yaml is the list of skill dicts like [{'name': 'Python', 'rating': 5}, ...]
        if not isinstance(skills_list_for_category_from_yaml, list):
            print(f"Warning: Expected a list of skills for category '{category_yaml_key}', but found {type(skills_list_for_category_from_yaml)}. Skipping this category.")
            continue

        for skill_item in skills_list_for_category_from_yaml:
            # Ensure skill_item is a dictionary before calling .get()
            if not isinstance(skill_item, dict):
                print(f"Warning: Expected a dictionary for a skill item in category '{category_yaml_key}', but found {type(skill_item)}. Skipping this item.")
                continue
            skill_name = skill_item.get('name') 
            rating = skill_item.get('rating')
            if skill_name: # Ensure skill_name is not None or empty
                organized_skills[display_category_title].append((skill_name, rating))

    # Optional: Sort skills within each category, e.g., by rating (desc) then name (asc)
    for category_title_key in organized_skills:
        # Sort by rating (descending, non-integers/None treated as 0), then by skill name (ascending)
        organized_skills[category_title_key].sort(key=lambda x: (-x[1] if isinstance(x[1], int) else 0, str(x[0])))

    with doc.create(Section("Skills", numbering=False)):
        doc.append(NoEscape(r"\vspace{-1.5em}")) # Adjust space as needed

        # Determine the order of categories to display.
        # Using sorted keys of organized_skills for consistent ordering.
        category_order = sorted(organized_skills.keys())

        table_content_tex = []
        first_category_processed = False
        for category_title in category_order:
            skills_list_for_category = organized_skills[category_title]
            if not skills_list_for_category: 
                continue

            # Add vertical space before new category header, if not the very first one.
            if first_category_processed:
                table_content_tex.append(NoEscape(r"\noalign{\vspace{0.6em}}"))
            
            # Category title as a multi-column row in the table, left-aligned.
            # Sanitize category_title here.
            sanitized_category_title = sanitize_latex_text(category_title)
            table_content_tex.append(NoEscape(r"\multicolumn{2}{@{}l@{}}{\textbf{" + sanitized_category_title + r"}} \\ "))
            # Add a little space after category title, before skills for that category.
            table_content_tex.append(NoEscape(r"\noalign{\vspace{0.2em}}"))

            for skill_name, rating in skills_list_for_category:
                if not skill_name: 
                    continue
                rating_dots = get_rating_dots(rating) 
                # Sanitize skill_name here.
                sanitized_skill_name = sanitize_latex_text(skill_name)
                table_content_tex.append(f"{sanitized_skill_name} & {rating_dots} \\")
            
            first_category_processed = True # Mark that at least one category has been processed

        if table_content_tex:
            # Define table spec here to match the content (2 columns)
            doc.append(NoEscape(r"\begin{tabular}{@{}>{\RaggedRight}p{3.5cm}@{}>{\RaggedLeft}p{3cm}@{}}"))
            doc.append(NoEscape("\n".join(table_content_tex)))
            doc.append(NoEscape(r"\end{tabular}"))

# --- Education Section ---

def create_latex_resume(data):
    """Creates the LaTeX resume document."""
    # Document setup with A4 paper and specific margins
    geometry_options = {
        "a4paper": True,
        "margin": "0.75in"
    }
    doc = Document(geometry_options=geometry_options, document_options=['10pt']) # Use 10pt font

    # Add necessary LaTeX packages
    doc.packages.append(Package('hyperref'))  # For clickable links
    doc.packages.append(Package('fontawesome5')) # For icons (email, phone, github, etc.)
    doc.packages.append(Package('amssymb'))    # For math symbols like \star
    doc.packages.append(Package('enumitem'))   # For custom lists (e.g., itemize, enumerate)
    doc.packages.append(Package('titlesec'))   # For section title customization
    doc.packages.append(Package('xcolor', options=['svgnames', 'x11names']))     # For color definitions
    doc.packages.append(Package('array'))      # For better table/column control
    doc.packages.append(Package('ragged2e'))   # For RaggedRight, RaggedLeft, Centering environments
    doc.packages.append(Package('setspace'))   # For line spacing control (\singlespacing, \onehalfspacing, etc.)
    doc.packages.append(Package('needspace'))  # To prevent awkward page breaks
    doc.packages.append(Package('helvet'))     # For Helvetica font
    doc.packages.append(Package('textcomp'))   # For \textbar and other text symbols

    # --- PREAMBLE CUSTOMIZATIONS ---
    # Define theme colors
    doc.preamble.append(Command('definecolor', ['themecolor', 'rgb', '0.15, 0.15, 0.35'])) # A dark navy/charcoal
    doc.preamble.append(Command('definecolor', ['linkcolor', 'rgb', '0.2, 0.4, 0.7']))    # A nice blue for links
    doc.preamble.append(Command('definecolor', ['lightgray', 'rgb', '0.92, 0.92, 0.92']))
    doc.preamble.append(Command('definecolor', ['mediumgray', 'rgb', '0.5, 0.5, 0.5']))
    doc.preamble.append(Command('definecolor', ['darkgray', 'rgb', '0.3, 0.3, 0.3']))

    # Hyperref setup for links
    doc.preamble.append(NoEscape(r'\hypersetup{colorlinks=true, linkcolor=linkcolor, urlcolor=linkcolor, citecolor=linkcolor}'))

    # Remove page numbers
    doc.preamble.append(Command('pagenumbering', 'gobble'))

    # Customize section titles (no numbering, specific style with a line)
    doc.preamble.append(NoEscape(r'\titleformat{\section}{\Large\scshape\bfseries\color{themecolor}}{}{0em}{}[\color{lightgray}\titlerule]'))
    doc.preamble.append(NoEscape(r'\titlespacing*{\section}{0pt}{1.2em}{0.8em}')) # Less space after section titles

    doc.preamble.append(NoEscape(r'\titleformat{\subsection}{\large\bfseries\color{themecolor}}{}{0em}{}'))
    doc.preamble.append(NoEscape(r'\titlespacing*{\subsection}{0pt}{1em}{0.5em}'))

    # Set default font to sans-serif (optional, many resumes use serif)
    doc.preamble.append(NoEscape(r'\renewcommand{\familydefault}{\sfdefault}'))

    # --- CONTACT INFORMATION ---
    if 'contact' in data:
        add_contact_info(doc, data['contact'])
    else:
        print("Warning: 'contact' not found in YAML data.")

    # --- Profile Section ---
    if 'profile' in data and data['profile']:
        add_profile_section(doc, data['profile'])
    else:
        print("Warning: 'profile' text not found in YAML data.")

    # --- Experience Section ---
    if 'experience' in data and data['experience']:
        add_experience_section(doc, data['experience'], section_title="Experience")
    else:
        print("Warning: 'experience' data not found in YAML.")

    # --- Personal Projects Section ---
    if 'personal_projects' in data and data['personal_projects']:
        add_formatted_contributions_section(doc, data['personal_projects'], section_title="Personal Projects")

    # --- Open Source Contributions Section ---
    if 'open_source_contributions' in data and data['open_source_contributions']:
        add_formatted_contributions_section(doc, data['open_source_contributions'], section_title="Open Source Contributions")

    # --- Skills Section ---
    if 'skills' in data and data['skills']:
        add_skills_section_updated(doc, data['skills'])

    # --- Education Section ---
    if 'education' in data and data['education']:
        add_education_section(doc, data['education'])

    return doc

if __name__ == "__main__":
    yaml_file_path = 'resume.yaml'
    resume_data = load_resume_data(yaml_file_path)

    if resume_data:
        print(f"Successfully loaded data from {yaml_file_path}")

        latex_document = create_latex_resume(resume_data) # Pass data here

        file_name = 'resume_generated'
        latex_document.generate_tex(file_name)
        print(f"Generated {file_name}.tex successfully.")

        try:
            latex_document.generate_pdf(file_name, clean_tex=False, compiler='pdflatex')
            print(f"Generated {file_name}.pdf successfully.")
        except Exception as e:
            print(f"Could not generate PDF: {e}")
            print("Please ensure you have a LaTeX distribution (like MiKTeX, TeX Live, or MacTeX) installed and in your PATH.")
    else:
        print(f"Could not generate resume. Please check {yaml_file_path}.")
