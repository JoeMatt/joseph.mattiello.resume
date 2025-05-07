#!/usr/bin/env python3
"""
Generate a GitHub-formatted README.md from resume.yaml
"""

import yaml
import os
from datetime import datetime

def load_yaml_data(file_path):
    """Load data from a YAML file."""
    with open(file_path, 'r', encoding='utf-8') as file:
        return yaml.safe_load(file)

def generate_markdown(resume_data):
    """Generate GitHub-formatted markdown from resume data."""
    md = []

    # Quick Install section
    md.append("# Joseph Mattiello's Interactive Resume")
    md.append("\n## Quick Install")
    md.append("\nView my interactive resume in your terminal by running:")
    md.append("\n```bash")
    md.append("curl -fsSL https://raw.githubusercontent.com/JoeMatt/joseph.mattiello.resume/master/install.sh | bash")
    md.append("```")
    md.append("\nor")
    md.append("\n```bash")
    md.append("wget -O- https://raw.githubusercontent.com/JoeMatt/joseph.mattiello.resume/master/install.sh | bash")
    md.append("```")
    md.append("\nRequirements: Swift, Git, `curl` or `wget`, `unzip`, and a terminal that supports ncurses.")
    md.append("\n") # Add an extra newline for spacing before the next section

    # Name as main header
    md.append(f"# {resume_data['name']}")
    
    # Contact information with icons
    md.append("\n## 📬 Contact Information")
    contact = resume_data.get('contact', {})
    contact_md = []
    
    if contact.get('email'):
        # Obfuscate email to prevent scraping
        email = contact['email']
        obfuscated_email = email.replace('@', ' [at] ').replace('.', ' [dot] ')
        contact_md.append(f"📧 Email: {obfuscated_email}")
    if contact.get('phone'):
        # Obfuscate phone number to prevent scraping
        phone = contact['phone']
        # If it's in the format "+1 (646) 771-8603", obfuscate it
        if phone.startswith('+'):
            # Keep country code but obfuscate the rest
            parts = phone.split(' ', 1)
            if len(parts) > 1:
                country_code = parts[0]
                rest = parts[1]
                obfuscated_phone = f"{country_code} xxx-xxx-xxxx"
                contact_md.append(f"📱 Phone: {obfuscated_phone}")
            else:
                # If format is different, just mask most digits
                obfuscated_phone = phone[:3] + '-xxx-xxxx'
                contact_md.append(f"📱 Phone: {obfuscated_phone}")
        else:
            # For other formats, just mask most digits
            obfuscated_phone = 'xxx-xxx-' + phone[-4:]
            contact_md.append(f"📱 Phone: {obfuscated_phone}")
    if contact.get('website'):
        contact_md.append(f"🌐 Website: [{contact['website']}]({contact['website']})")
    if contact.get('linkedin'):
        contact_md.append(f"👔 LinkedIn: [{contact['linkedin'].split('/')[-1]}]({contact['linkedin']})")
    if contact.get('github'):
        contact_md.append(f"💻 GitHub: [{contact['github'].split('/')[-1]}]({contact['github']})")
    
    md.append("\n" + "\n".join(contact_md))
    
    # Profile/Summary
    if resume_data.get('profile'):
        md.append("\n## 📝 Summary")
        if isinstance(resume_data['profile'], list):
            for paragraph in resume_data['profile']:
                md.append(f"\n{paragraph}")
        else:
            md.append(f"\n{resume_data['profile']}")
    
    # Experience
    if resume_data.get('experience'):
        md.append("\n## 💼 Experience")
        for job in resume_data['experience']:
            job_title = f"### {job['title']} | {job['company']}"
            if job.get('location'):
                job_title += f" | {job['location']}"
            md.append(f"\n{job_title}")
            
            # Date range
            date_range = f"*{job['start_date']} - {job.get('end_date', 'Present')}*"
            md.append(f"\n{date_range}")
            
            # Responsibilities
            if job.get('responsibilities'):
                md.append("\n**Responsibilities:**")
                for resp in job['responsibilities']:
                    md.append(f"- {resp}")
    
    # Skills
    if resume_data.get('skills'):
        md.append("\n## 🛠️ Skills")
        
        for category, skills in resume_data['skills'].items():
            md.append(f"\n### {category.replace('_', ' ').title()}")
            
            # Check if skills is a list of dictionaries with name and rating
            if isinstance(skills, list) and skills and isinstance(skills[0], dict) and 'name' in skills[0]:
                # Sort by rating (descending) then by name
                sorted_skills = sorted(skills, key=lambda x: (-x.get('rating', 0), x['name']))
                
                # Create a table for skills with ratings
                md.append("\n| Skill | Proficiency |")
                md.append("| --- | --- |")
                
                for skill in sorted_skills:
                    # Create a visual representation of the rating
                    rating = skill.get('rating', 0)
                    rating_display = "⭐" * rating
                    md.append(f"| {skill['name']} | {rating_display} |")
            else:
                # Simple list of skills
                for skill in skills:
                    if isinstance(skill, dict) and 'name' in skill:
                        md.append(f"- {skill['name']}")
                    else:
                        md.append(f"- {skill}")
    
    # Education
    if resume_data.get('education'):
        md.append("\n## 🎓 Education")
        for edu in resume_data['education']:
            edu_line = f"### {edu['degree']} | {edu['institution']}"
            if edu.get('graduation_year'):
                edu_line += f" | {edu['graduation_year']}"
            md.append(f"\n{edu_line}")
            
            if edu.get('details'):
                md.append(f"\n{edu['details']}")
    
    # Open Source Contributions
    if resume_data.get('open_source_contributions'):
        md.append("\n## 🔄 Open Source Contributions")
        for project in resume_data['open_source_contributions']:
            md.append(f"\n### {project['name']}")
            
            if project.get('description'):
                md.append(f"\n{project['description']}")
            
            if project.get('links'):
                md.append("\n**Links:**")
                for link in project['links']:
                    md.append(f"- [{link['title']}]({link['url']})")
    
    # Personal Projects
    if resume_data.get('personal_projects'):
        md.append("\n## 🚀 Personal Projects")
        for project in resume_data['personal_projects']:
            md.append(f"\n### {project['name']}")
            
            if project.get('description'):
                md.append(f"\n{project['description']}")
            
            if project.get('technologies'):
                if isinstance(project['technologies'], list):
                    tech_list = ", ".join(project['technologies'])
                    md.append(f"\n**Technologies:** {tech_list}")
                else:
                    md.append(f"\n**Technologies:** {project['technologies']}")
            
            links = []
            if project.get('app_store_link') and project['app_store_link']:
                links.append(f"[App Store]({project['app_store_link']})")
            
            if project.get('links'):
                for link in project['links']:
                    links.append(f"[{link['title']}]({link['url']})")
            
            if links:
                md.append("\n**Links:** " + " | ".join(links))
    
    # Footer
    md.append("\n---")
    md.append(f"\n*Last updated: {datetime.now().strftime('%B %d, %Y')}*")
    md.append("\n*This README was automatically generated from my [resume.yaml](resume.yaml) file.*")
    md.append("\n*Contact information has been obfuscated to prevent automated scraping.*")
    
    return "\n".join(md)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    yaml_path = os.path.join(script_dir, 'resume.yaml')
    readme_path = os.path.join(script_dir, 'README.md')
    
    # Load resume data
    resume_data = load_yaml_data(yaml_path)
    
    # Generate markdown
    markdown = generate_markdown(resume_data)
    
    # Write to README.md
    with open(readme_path, 'w', encoding='utf-8') as file:
        file.write(markdown)
    
    print(f"Successfully generated README.md from resume.yaml")

if __name__ == "__main__":
    main()
