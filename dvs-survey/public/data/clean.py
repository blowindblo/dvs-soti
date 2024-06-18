import pandas as pd

df = pd.read_csv('dvs_survey_analysis.csv')

# Create unique identifier for inspirations
name_to_id = {name: idx for idx, name in enumerate(df['inspiration'].unique())}
df['inspirID'] = df['inspiration'].map(name_to_id)

# Remove duplicates
df = df.drop_duplicates(subset = ['ID','inspiration'])
counts = df['inspiration'].value_counts()
# Map the counts to a new column
df['count'] = df['inspiration'].map(counts)

# Convert to title case
df['inspiration'] = df['inspiration'].str.title()
df['type'] = df['type'].str.title()
df.loc[df['inspiration'] == 'Nyt', 'inspiration'] = 'NYT'
df.loc[df['inspiration'] == 'Ieee', 'inspiration'] = 'IEEE'

prefix = 'ToolsForDV_'
excluded_columns = ['ToolsForDV_PenPaper', 'ToolsForDV_PowerPoint', 'ToolsForDV_Other__', 'ToolsForDV_']
selected_cols = [col for col in df.columns if col.startswith(prefix) and col not in excluded_columns]

# Replace blanks with 0 and non-blanks with 1
df[selected_cols] = df[selected_cols].map(lambda x: 0 if pd.isna(x) or x == '' else 1)

column_sums = df[selected_cols].sum()

# Step 3: Sort columns based on their sums in descending order
sorted_columns = column_sums.sort_values(ascending=False)

# Step 4: Select the top 10 columns
top_10_columns = sorted_columns.head(10).index

# Step 5: Create a new DataFrame with only the top 10 filtered columns, while keeping the other columns intact
df_top_10 = pd.concat([df[top_10_columns], df.drop(selected_cols, axis=1)], axis=1)


# df_top_10.to_csv('dvs_survey_analysis_id.csv', index=False)

# Create nodes df for network graph
df_nodes = df[['inspirID','inspiration','type','count']].drop_duplicates()
df_nodes = df_nodes.rename(columns = {'inspiration': 'inspir'})
# print(df['inspirID'])

#not coded but manually edited twitter community -> community
# reddit -> community
# tidytues data fam -> community
# manually remove rprefix from column headers


# df_nodes.to_csv('dvs_nodes.csv', index=False)