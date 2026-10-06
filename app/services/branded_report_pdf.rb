class BrandedReportPdf < ReportPdf
  GREEN = '194B3D'
  INK = '192D24'
  MUTED = '61716A'
  LINE = 'DCE4DC'

  def render
    pdf = Prawn::Document.new(page_size: 'A4', margin: [105, 38, 55, 38])
    setup_font(pdf)
    draw_header(pdf)
    pdf.text @data[:title], size: 23, style: :bold, color: INK
    pdf.move_down 6
    pdf.text(@data[:subtitle] || 'Resumo dos movimentos do estabelecimento.', size: 9, color: MUTED)
    pdf.move_down 14
    y = pdf.cursor
    pdf.fill_color GREEN
    pdf.fill_rounded_rectangle [0, y], pdf.bounds.width, 34, 8
    pdf.fill_color 'FFFFFF'
    pdf.text_box @data[:period], at: [12, y - 10], width: pdf.bounds.width - 24, height: 16, size: 10, style: :bold
    pdf.move_down 48
    draw_stats(pdf)
    draw_cash_status(pdf) if @data[:status]
    draw_chart(pdf, @data[:chart_rows]) if @data[:chart_rows].present?
    Array(@data[:sections]).each do |section|
      next_page(pdf) if section[:new_page]
      keep_short_table_together(pdf, section)
      heading(pdf, section[:title])
      if section[:chart_rows]
        draw_chart(pdf, section[:chart_rows])
      else
        draw_table(pdf, section[:headers] || ['Item', 'Valor'], section[:rows] || [])
      end
    end
    if @data[:pending_tables].present?
      heading(pdf, 'Mesas por pagar')
      pdf.text @data[:pending_tables].join(' / '), size: 9, color: MUTED
    end
    if @data[:notes].present?
      heading(pdf, 'Como interpretar este relatório')
      @data[:notes].each do |note|
        ensure_space(pdf, pdf.height_of(note, size: 8) + 10)
        pdf.text note, size: 8, color: MUTED
        pdf.move_down 8
      end
    end
    if @data[:payment_rows].present?
      next_page(pdf)
      heading(pdf, 'Pagamentos detalhados')
      pdf.text 'Todos os movimentos incluídos no período selecionado.', size: 9, color: MUTED
      pdf.move_down 10
      draw_table(pdf, ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor'], @data[:payment_rows], weights: [1.2, 0.7, 0.7, 0.7, 2, 1.1, 1.1], size: 7)
    end
    draw_footer(pdf)
    pdf.render
  end

  private

  def keep_short_table_together(pdf, section)
    rows = section[:rows] || []
    return if rows.empty? || rows.size > 8
    headers = section[:headers] || ['Item', 'Valor']
    size = headers.size >= 8 ? 6.5 : 8
    weights = [headers.size >= 8 ? 1.7 : 2.5] + Array.new(headers.size - 1, 1.2)
    widths = weights.map { |w| pdf.bounds.width * w / weights.sum }
    height = row_height(pdf, headers, widths, size, true) + rows.sum { |row| row_height(pdf, row, widths, size, false) } + 46
    ensure_space(pdf, height) if height < pdf.bounds.height
  end

  def draw_header(pdf)
    cursor = pdf.cursor
    pdf.canvas do
      pdf.fill_color 'F8F5EF'
      pdf.fill_rectangle [0, pdf.page.dimensions[3]], pdf.page.dimensions[2], pdf.page.dimensions[3]
    end
    pdf.bounding_box([0, pdf.bounds.top + 72], width: pdf.bounds.width, height: 52) do
      logo = Rails.root.join('app/assets/images/bocato-logo.png')
      pdf.image logo.to_s, at: [0, 52], fit: [110, 36] if File.file?(logo)
      pdf.fill_color GREEN
      pdf.text_box @data[:establishment].to_s, at: [150, 48], width: pdf.bounds.width - 150, height: 22, align: :right, size: 10, style: :bold, overflow: :shrink_to_fit
      pdf.fill_color MUTED
      pdf.text_box "Gerado em #{Time.current.in_time_zone.strftime('%d/%m/%Y %H:%M')}", at: [150, 25], width: pdf.bounds.width - 150, height: 13, align: :right, size: 8
      pdf.stroke_color LINE
      pdf.stroke_line [0, 1], [pdf.bounds.width, 1]
    end
    pdf.move_cursor_to cursor
  end

  def next_page(pdf)
    pdf.start_new_page
    draw_header(pdf)
  end

  def draw_stats(pdf)
    columns = @data[:stats].size == 6 ? 3 : 2
    width = (pdf.bounds.width - (columns - 1) * 10) / columns
    @data[:stats].each_slice(columns) do |row|
      ensure_space(pdf, 88)
      y = pdf.cursor
      row.each_with_index do |(label, value), i|
        x = i * (width + 10)
        pdf.fill_color 'FFFFFF'; pdf.stroke_color LINE
        pdf.fill_and_stroke_rounded_rectangle [x, y], width, 75, 10
        pdf.fill_color MUTED
        pdf.text_box label.to_s, at: [x + 12, y - 12], width: width - 24, height: 25, size: 8, overflow: :shrink_to_fit
        pdf.fill_color GREEN
        pdf.text_box value.to_s, at: [x + 12, y - 40], width: width - 24, height: 26, size: 20, style: :bold, overflow: :shrink_to_fit
      end
      pdf.move_down 85
    end
  end

  def heading(pdf, title)
    ensure_space(pdf, 84)
    pdf.move_down 16
    pdf.text title, size: 13, style: :bold, color: INK
    pdf.move_down 9
  end

  def draw_chart(pdf, rows)
    if rows.blank?
      pdf.text 'Sem dados para este período.', size: 9, color: MUTED
      return
    end
    max = [rows.map { |r| r[:value].to_f }.max.to_f, 1].max
    label_width, value_width = 120, 95
    bar_width = pdf.bounds.width - label_width - value_width - 20
    rows.each do |row|
      ensure_space(pdf, 23)
      y = pdf.cursor
      pdf.fill_color MUTED
      pdf.text_box row[:label].to_s, at: [0, y], width: label_width - 8, height: 18, size: 8, overflow: :shrink_to_fit
      pdf.fill_color row[:value].to_f == max ? 'F5B055' : GREEN
      pdf.fill_rounded_rectangle [label_width, y - 2], [bar_width * row[:value].to_f / max, 2].max, 11, 3
      pdf.fill_color INK
      pdf.text_box row[:display].to_s, at: [label_width + bar_width + 10, y], width: value_width, height: 18, size: 8, align: :right, overflow: :shrink_to_fit
      pdf.move_down 23
    end
  end

  def draw_table(pdf, headers, rows, weights: nil, size: nil)
    if rows.empty?
      pdf.text 'Sem dados para este período.', size: 9, color: MUTED
      return
    end
    size ||= headers.size >= 8 ? 6.5 : 8
    weights ||= [headers.size >= 8 ? 1.7 : 2.5] + Array.new(headers.size - 1, 1.2)
    widths = weights.map { |w| pdf.bounds.width * w / weights.sum }
    ensure_space(pdf, row_height(pdf, headers, widths, size, true) + row_height(pdf, rows.first, widths, size, false))
    paint_row(pdf, headers, widths, size, true, 0)
    rows.each_with_index do |row, index|
      height = row_height(pdf, row, widths, size, false)
      if pdf.cursor < height + 4
        next_page(pdf)
        paint_row(pdf, headers, widths, size, true, 0)
      end
      paint_row(pdf, row, widths, size, false, index)
    end
  end

  def row_height(pdf, row, widths, size, header)
    row.each_with_index.map { |v, i| pdf.height_of(v.to_s, width: widths[i] - 14, size: size, style: header ? :bold : :normal) + 16 }.max.ceil
  end

  def paint_row(pdf, row, widths, size, header, index)
    height = row_height(pdf, row, widths, size, header)
    y = pdf.cursor
    pdf.fill_color header ? GREEN : (index.even? ? 'FFFFFF' : 'F0F4EE')
    pdf.fill_rectangle [0, y], pdf.bounds.width, height
    pdf.fill_color header ? 'FFFFFF' : INK
    x = 0
    row.each_with_index do |value, i|
      pdf.text_box value.to_s, at: [x + 7, y - 8], width: widths[i] - 14, height: height - 12, size: size,
                   style: header ? :bold : :normal, align: i.zero? ? :left : :right
      x += widths[i]
    end
    pdf.move_down height
  end

  def draw_footer(pdf)
    pdf.repeat(:all) do
      pdf.stroke_color LINE
      pdf.stroke_line [0, -20], [pdf.bounds.width, -20]
      pdf.text_box 'Bocato / Relatório do estabelecimento', at: [0, -29], width: pdf.bounds.width - 120, height: 12, size: 8, color: MUTED
    end
    pdf.number_pages '<page> / <total>', at: [pdf.bounds.width - 100, -29], width: 100, align: :right, size: 8, color: MUTED
  end

  def ensure_space(pdf, height)
    next_page(pdf) if pdf.cursor < height
  end
end
