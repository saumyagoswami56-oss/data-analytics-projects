# News Aggregator Project
This Python-based project aggregates news articles using the NewsAPI and enhances
them with additional metadata via web scraping.
It features a GUI using `ipywidgets`, object-oriented design, data cleaning, and
unit testing for robustness.
## 🔧 How to Run
1. Install dependencies:
```bash
pip install newsapi-python beautifulsoup4 pandas matplotlib ipywidgets requests-
cache
```
2. Add your NewsAPI key in the script where the `NewsApiClient` is initialized.
3. Run the notebook cell-by-cell in Jupyter.
## 🔧 Features
- NewsAPI integration
- Web scraping with BeautifulSoup
- Article class to encapsulate data
- Data cleaning and visualization
- GUI using `ipywidgets`
- Unit testing using `unittest`
## 🔧 Required Files
- `News_Aggregator.ipynb`: Main notebook
- `news_articles_au.csv`: Exported article data
## 🔧 Note
You must have a valid NewsAPI key. You can sign up at: https://newsapi.org
