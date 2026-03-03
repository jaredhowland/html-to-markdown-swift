# R Markdown Demo {#rmarkdown-demo}

R Markdown combines R code with Markdown text to produce reproducible documents.

## Mathematical Equations {#math}

Inline: $\alpha + \beta = \gamma$

$$
\int_0^\infty e^{-x^2} dx = \frac{\sqrt{\pi}}{2}
$$

## Figures with Captions {#figures}

![Figure 1: Relationship between variables X and Y (n=150)](scatter-plot.png)

![Figure 2: Distribution of response variable](histogram.png)

## Tabbed Sections {#tabsets}

## Summary

Summary statistics and key findings.

## Details

Detailed methodology and analysis steps.

## Code

Source code and reproducible scripts.

## Terminology {#definition-lists}

R Markdown
:   A format combining R code chunks with Markdown narrative text.
knitr
:   An R package that executes code chunks and weaves output into documents.
Pandoc
:   The universal document converter that transforms Markdown to HTML, PDF, and more.

## Results Table {#tables}

| Variable | Mean  | SD   | p-value   |
|----------|-------|------|-----------|
| Height   | 170.2 | 8.4  | &lt;0.001 |
| Weight   | 68.5  | 12.1 | &lt;0.001 |
| BMI      | 23.7  | 3.2  | 0.043     |
