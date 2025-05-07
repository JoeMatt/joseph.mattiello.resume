import yaml
import os
from jinja2 import Environment, FileSystemLoader
from weasyprint import HTML

def load_resume_data(yaml_file_path):
    try:
        with open(yaml_file_path, 'r', encoding='utf-8') as file:
            data = yaml.safe_load(file)
        print(f"Successfully loaded data from {os.path.basename(yaml_file_path)}")
        return data
    except FileNotFoundError:
        print(f"Error: The file {yaml_file_path} was not found.")
        return None
    except yaml.YAMLError as e:
        print(f"Error parsing YAML file: {e}")
        return None

def main():
    # Define paths relative to the script's directory or a common project root
    # Assuming script is in project_root/joseph.mattiello.resume/
    # and other files are relative to this.
    project_root = os.path.dirname(os.path.abspath(__file__))

    yaml_file = os.path.join(project_root, 'resume.yaml')
    template_dir = os.path.join(project_root, 'templates')
    template_file = 'resume_template.html' # Relative to template_dir
    static_dir = os.path.join(project_root, 'static')
    css_file = 'style.css' # Relative to static_dir
    output_dir = os.path.join(project_root, 'output')
    output_html_file = os.path.join(output_dir, 'resume.html')
    output_pdf_file = os.path.join(output_dir, 'resume.pdf')

    # Create output, templates, and static directories if they don't exist
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(template_dir, exist_ok=True)
    os.makedirs(static_dir, exist_ok=True)

    # Load resume data
    resume_data = load_resume_data(yaml_file)
    if not resume_data:
        return

    # Set up Jinja2 environment
    env = Environment(loader=FileSystemLoader(template_dir), autoescape=True)
    try:
        template = env.get_template(template_file)
    except Exception as e:
        print(f"Error loading template '{template_file}': {e}")
        print(f"Please ensure '{template_file}' exists in '{template_dir}'.")
        # Create a dummy template file if it doesn't exist for first run
        dummy_template_path = os.path.join(template_dir, template_file)
        if not os.path.exists(dummy_template_path):
            with open(dummy_template_path, 'w', encoding='utf-8') as tf:
                tf.write('<h1>Template not found - Dummy Created</h1><p>{{ resume_data.contact_info.name }}</p>')
            print(f"Created a dummy template at {dummy_template_path}. Please replace it with your actual template.")
        return

    # Render HTML template with data
    html_content = template.render(resume_data=resume_data)

    # Save the rendered HTML
    try:
        with open(output_html_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        print(f"Successfully generated HTML: {output_html_file}")
    except IOError as e:
        print(f"Error writing HTML file: {e}")
        return

    # Convert HTML to PDF using WeasyPrint
    try:
        # The base_url for WeasyPrint helps resolve relative paths in the HTML (e.g., for CSS, images)
        # If HTML file is output/resume.html and CSS is ../static/style.css,
        # then base_url should point to the directory *containing* 'output' and 'static'.
        # In our case, project_root is fine if the paths in HTML are like /static/style.css or correctly relative.
        # The template uses: <link rel="stylesheet" href="../static/style.css">
        # If the HTML is in output_dir, then base_url should be project_root for this relative path to work.
        html_doc = HTML(filename=output_html_file, base_url=project_root)
        html_doc.write_pdf(output_pdf_file)
        print(f"Successfully generated PDF: {output_pdf_file}")

    except Exception as e:
        print(f"Error generating PDF with WeasyPrint: {e}")
        print("Please ensure WeasyPrint and its dependencies (Pango, Cairo, etc.) are correctly installed.")
        print("For macOS, try: brew install pango cairo libffi gdk-pixbuf")
        print("For other OS, check WeasyPrint documentation: https://doc.courtbouillon.org/weasyprint/stable/first_steps.html#installation")

if __name__ == '__main__':
    main()
