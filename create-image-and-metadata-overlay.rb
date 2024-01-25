require 'mini_magick'
require 'json'
require 'fileutils'

# 画像ファイルが格納されているディレクトリのパス
input_file_paths = [
  "./pai/daylight",
  "./pai/blue",
  "./pai/roomlight-dark"
]

datasets = [
  { "loop_count" => 10, "outdir" => "train" },
  { "loop_count" => 3, "outdir" => "test" }
]

# 出力フォルダ
base_folder = "mahjong-masainox"
sub_folder = Time.now.to_i

# fg_imageのオフセットの範囲計算
def calculate_geometry(fg_image, bg_image)
  left = rand(0..(bg_image.width - fg_image.width))
  top = rand(0..(bg_image.height - fg_image.height))
  return left, top
end

# ループ処理
datasets.each do |dataset|

  # 出力ディレクトリ
  output_directory = "./#{base_folder}/#{sub_folder}/#{dataset['outdir']}"
  FileUtils.mkdir_p(output_directory) unless File.exist?(output_directory)
  json_file_path = File.join(output_directory, "#{dataset['outdir']}.manifest.data")
  puts "#{dataset['outdir']} manifest file is #{json_file_path}"

  total_iterations = dataset["loop_count"]

  total_iterations.times do |iteration|
    print "\rProcessing #{iteration + 1}/#{total_iterations}"
    print "\rProcessing #{iteration + 1}/#{total_iterations} for #{dataset['outdir']}"
    STDOUT.flush

    # ディレクトリをランダムに決めて、中の画像ファイルを取得
    input_file_path = input_file_paths.sample
    image_files = Dir.glob("#{input_file_path}/*.jpg")


    # N個の画像をランダムに選ぶ
    number_of_images = rand(10..13)
    selected_image_paths = image_files.sample(number_of_images)
    selected_image_text = selected_image_paths.map { |path| File.basename(path, File.extname(path)) }.join("-")

    # 中間ファイルの定義
    merged_image_path = File.join(output_directory, "concat-#{iteration}.jpg")

    # 背景とマージされたファイルの定義
    outfile = "#{Time.now.to_i}_#{selected_image_text}.jpg"
    output_file_path = File.join(output_directory, outfile)

    # 画像を横に結合
    montage = MiniMagick::Tool::Montage.new
    montage.geometry "+0+0"
    selected_image_paths.each { |file_path| montage << file_path }
    montage << '-tile' << "#{number_of_images}x1"
    montage << merged_image_path
    montage.call
    

    fg_image = MiniMagick::Image.open(merged_image_path)
    bg_image_file = Dir.glob("background/image_*.jpg").sample
    bg_image = MiniMagick::Image.open(bg_image_file)

    left_offset, top_offset = calculate_geometry(fg_image, bg_image)

    result = bg_image.composite(fg_image) do |c|
      c.geometry "+#{left_offset}+#{top_offset}"
    end

    result.write output_file_path

    # 画像情報を取得するメソッド
    def get_image_info(image_path)
      image = MiniMagick::Image.open(image_path)
      {
        "file_name" => File.basename(image_path),
        "class_id" => File.basename(image_path).split("-")[0].to_i,
        "height" => image.height,
        "width" => image.width
      }
    end

    # 画像の位置情報を格納する配列
    annotations = []
    source_ref = outfile
    image_size = { "width" => bg_image.width, "height" => bg_image.height, "depth" => 3 }

    # 画像情報を取得し、位置情報を計算
    selected_image_paths.each do |path|
      image_info = get_image_info(path)
      annotations << {
        "class_id" => image_info["class_id"],
        "top" => top_offset,
        "left" => left_offset,
        "height" => image_info["height"],
        "width" => image_info["width"]
      }

      left_offset += image_info["width"]
    end

    # 出力データを生成
    output_data = {
      "source_ref" => "s3://#{base_folder}/#{sub_folder}/#{dataset['outdir']}/" + outfile,
      "image_size" => image_size,
      "annotations" => annotations
    }

    # 出力データをJSONファイルに書き込む
    File.open(json_file_path, "a") do |file|
      file.puts JSON.generate(output_data)
    end

    # 中間ファイルを消す
    Dir.glob(File.join(output_directory, 'concat-*.jpg')).each do |file|
      File.delete(file) if File.exist?(file)
    end

  end

  puts "\nRun following command:"
  puts "ruby create-manifest.rb #{json_file_path}"

end

