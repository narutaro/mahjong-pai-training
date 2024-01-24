require 'mini_magick'
require 'json'
require 'fileutils'

# 画像ファイルが格納されているディレクトリのパス
directory_path = "./pai/daylight"

datasets = [
  { "loop_count" => 1000, "outdir" => "train" },
  { "loop_count" => 100, "outdir" => "test" }
]

# 出力フォルダ
base_folder = "mahjong-x"
sub_folder = "v1"

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
    # ディレクトリ内の画像ファイルを取得
    image_files = Dir.glob("#{directory_path}/*.jpg")


    # N個の画像をランダムに選ぶ
    number_of_images = rand(10..13)
    selected_image_paths = image_files.sample(number_of_images)
    selected_image_text = selected_image_paths.map { |path| File.basename(path, File.extname(path)) }.join("-")

    # 画像を横に結合
    background_width = 1920
    background_height = 1080
    merged_image_path = File.join(output_directory, "concat-#{iteration}.jpg")

    montage = MiniMagick::Tool::Montage.new
    montage.geometry "+0+0"
    selected_image_paths.each { |file_path| montage << file_path }
    montage << '-tile' << "#{number_of_images}x1"
    montage << merged_image_path
    montage.call

    # 結合画像のサイズを取得
    concat_image = MiniMagick::Image.open(merged_image_path)
    width_of_concat_image = concat_image.width
    height_of_concat_image = concat_image.height

    # 画像内で結合画像を中心に配置するための開始位置（topとleft）を計算
    left_offset = (background_width - width_of_concat_image) / 2
    top_offset = (background_height - height_of_concat_image) / 2

    # 余白を追加して正確に指定サイズにリサイズ
    outfile = "#{Time.now.to_i}_#{selected_image_text}_#{background_width}x#{background_height}.jpg"
    output_file_path = File.join(output_directory, outfile)
    resized_image = MiniMagick::Image.open(merged_image_path)
    resized_image.combine_options do |c|
      c.gravity "center"
      c.extent "#{background_width}x#{background_height}"
      c.background "#00a17f"
    end
    resized_image.write(output_file_path)

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
    image_size = { "width" => background_width, "height" => background_height, "depth" => 3 }

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

  puts ""
  puts "ruby cm.rb ./#{base_folder}/#{sub_folder}/#{dataset['outdir']}/#{outfile}"

end

