module TablesHelper
  def table_svg(table)
    safe_join([
      content_tag(:rect, nil, x: 20, y: 35, width: 160, height: 110, rx: 24, class: 'table-visual-surface'),
      content_tag(:circle, nil, cx: 20, cy: 90, r: 12, class: 'table-visual-leg'),
      content_tag(:circle, nil, cx: 180, cy: 90, r: 12, class: 'table-visual-leg'),
      content_tag(:text, table.number, x: 100, y: 105, class: 'table-visual-number', 'text-anchor': 'middle')
    ])
      .then { |contents| content_tag(:svg, contents, xmlns: 'http://www.w3.org/2000/svg', viewBox: '0 0 200 180', role: 'img', aria: { label: "Mesa #{table.number}" }, class: 'table-visual') }
  end
end
