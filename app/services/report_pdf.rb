require 'prawn'

class ReportPdf
  GREEN = '1F6F54'
  INK = '1E3D35'
  MUTED = '60736C'
  LINE = 'D9E4DC'
  FONT_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
  FONT_BOLD_PATH = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

  def initialize(data)
    @data = data
  end

  def render
    Prawn::Document.new(page_size: 'A4', margin: [36, 36, 42, 36]) do |pdf|
      setup_font(pdf)
      draw_header(pdf)
      draw_stats(pdf)
      pdf.move_down 18
      draw_chart(pdf) if @data[:chart_rows].present?
      draw_sections(pdf)
      draw_cash_details(pdf) if @data[:pending_tables]
      draw_payments(pdf) if @data[:payment_rows].present?
      draw_footer(pdf)
    end.render
  end

  private

  def setup_font(pdf)
    return unless File.exist?(FONT_PATH) && File.exist?(FONT_BOLD_PATH)

    pdf.font_families.update(
      'DejaVu Sans' => {
        normal: FONT_PATH,
        bold: FONT_BOLD_PATH
      }
    )
    pdf.font 'DejaVu Sans'
  end

  def draw_header(pdf)
    pdf.fill_color INK
    pdf.text 'Relatórios e caixa', size: 22, style: :bold
    pdf.move_down 5
    pdf.fill_color GREEN
    pdf.text @data[:title], size: 15, style: :bold
    pdf.move_down 3
    pdf.fill_color MUTED
    pdf.text "Período: #{@data[:period]}  |  Gerado em: #{Time.current.strftime('%d/%m/%Y %H:%M')}", size: 9
    pdf.move_down 18
  end

  def draw_stats(pdf)
    cell_width = pdf.bounds.width / 2
    @data[:stats].each_slice(2) do |pair|
      top = pdf.cursor
      pair.each_with_index do |(label, value), index|
        x = index * cell_width
        pdf.fill_color 'F5F8F4'
        pdf.fill_rectangle [x, top], cell_width - 6, 44
        pdf.fill_color LINE
        pdf.stroke_rectangle [x, top], cell_width - 6, 44
        pdf.fill_color MUTED
        pdf.text_box label.to_s, at: [x + 8, top - 8], width: cell_width - 22, height: 13, size: 8
        pdf.fill_color INK
        pdf.text_box value.to_s, at: [x + 8, top - 25], width: cell_width - 22, height: 17, size: 12, style: :bold
      end
      pdf.move_down 52
    end
  end

  def draw_chart(pdf)
    ensure_space(pdf, 150)
    pdf.fill_color INK
    pdf.text 'Evolução / distribuição', size: 13, style: :bold
    pdf.move_down 8
    max = [@data[:chart_rows].map { |row| row[:value].to_f }.max.to_f, 1].max
    width = pdf.bounds.width - 110
    @data[:chart_rows].first(12).each do |row|
      ensure_space(pdf, 22)
      label = row[:label].to_s
      label = "#{label[0, 24]}…" if label.length > 25
      y = pdf.cursor
      pdf.fill_color MUTED
      pdf.text_box label, at: [0, y], width: 92, height: 12, size: 8, overflow: :shrink_to_fit
      bar_width = width * row[:value].to_f / max
      pdf.fill_color GREEN
      pdf.rounded_rectangle [102, y - 1], [bar_width, 2].max, 10, 3
      pdf.fill_color INK
      pdf.text_box row[:display].to_s, at: [102 + [bar_width, 2].max + 6, y], width: 70, height: 12, size: 8, overflow: :shrink_to_fit
      pdf.move_down 17
    end
  end

  def draw_sections(pdf)
    Array(@data[:sections]).each do |section|
      next if section[:rows].blank?

      ensure_space(pdf, 100)
      pdf.move_down 16
      pdf.fill_color INK
      pdf.text section[:title], size: 13, style: :bold
      pdf.move_down 7
      draw_rows(pdf, section[:rows].first(25), true)
    end
  end

  def draw_rows(pdf, rows, include_header = false)
    rows = [['Item', 'Valor']] + rows if include_header
    width = pdf.bounds.width
    first_column = width * 0.68
    row_height = 22
    rows.each_with_index do |row, index|
      ensure_space(pdf, row_height + 4)
      top = pdf.cursor
      pdf.fill_color(index.zero? ? GREEN : (index.odd? ? 'F5F8F4' : 'FFFFFF'))
      pdf.fill_rectangle [0, top], width, row_height
      pdf.fill_color LINE
      pdf.stroke_rectangle [0, top], width, row_height
      pdf.stroke_line [first_column, top], [first_column, top - row_height]
      pdf.fill_color(index.zero? ? 'FFFFFF' : INK)
      pdf.text_box row[0].to_s, at: [6, top - 6], width: first_column - 12, height: 14, size: 9, style: index.zero? ? :bold : :normal, overflow: :shrink_to_fit
      pdf.text_box row[1].to_s, at: [first_column + 6, top - 6], width: width - first_column - 12, height: 14, size: 9, style: index.zero? ? :bold : :normal, align: :right, overflow: :shrink_to_fit
      pdf.move_down row_height
    end
  end

  def draw_payments(pdf)
    pdf.start_new_page
    pdf.fill_color INK
    pdf.text 'Pagamentos detalhados', size: 15, style: :bold
    pdf.move_down 4
    pdf.fill_color MUTED
    pdf.text 'Todos os movimentos incluídos no período selecionado.', size: 9
    pdf.move_down 10

    width = pdf.bounds.width
    widths = [62, 40, 45, 40, 140, 90, width - 417]
    headers = ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor']
    draw_payment_row(pdf, headers, widths, true)
    @data[:payment_rows].each do |row|
      ensure_space(pdf, 20) { draw_payment_header(pdf, widths) }
      draw_payment_row(pdf, row, widths, false)
    end
  end

  def draw_payment_header(pdf, widths)
    pdf.fill_color INK
    pdf.text 'Pagamentos detalhados', size: 15, style: :bold
    pdf.move_down 10
    draw_payment_row(pdf, ['Data', 'Hora', 'Pedido', 'Mesa', 'Funcionário', 'Método', 'Valor'], widths, true)
  end

  def draw_payment_row(pdf, row, widths, header)
    height = header ? 22 : 19
    x = 0
    top = pdf.cursor
    row.each_with_index do |value, index|
      cell_width = widths[index]
      pdf.fill_color(header ? GREEN : (index.even? ? 'F5F8F4' : 'FFFFFF'))
      pdf.fill_rectangle [x, top], cell_width, height
      pdf.fill_color LINE
      pdf.stroke_rectangle [x, top], cell_width, height
      pdf.fill_color header ? 'FFFFFF' : INK
      pdf.text_box value.to_s, at: [x + 4, top - 5], width: cell_width - 8, height: height - 5, size: header ? 7 : 6.5, style: header ? :bold : :normal, align: index == 6 ? :right : :left, overflow: :shrink_to_fit
      x += cell_width
    end
    pdf.move_down height
  end

  def draw_cash_details(pdf)
    return if @data[:pending_tables].blank?

    ensure_space(pdf, 50)
    pdf.move_down 16
    pdf.fill_color INK
    pdf.text 'Mesas por pagar', size: 13, style: :bold
    pdf.move_down 6
    pdf.fill_color MUTED
    pdf.text @data[:pending_tables].join('  ·  '), size: 9
  end

  def draw_footer(pdf)
    pdf.number_pages 'Página <page> de <total>', at: [pdf.bounds.right - 100, 0], align: :right, size: 8, color: MUTED
  end

  def ensure_space(pdf, height)
    if pdf.cursor < height + 24
      pdf.start_new_page
      yield if block_given?
    end
  end
end
