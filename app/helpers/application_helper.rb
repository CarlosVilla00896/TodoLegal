module ApplicationHelper
  require 'bcrypt'

  def current_user_is_admin
    current_user && current_user.permissions.find_by_name("Admin")
  end

  def current_user_is_editor
    current_user && (current_user.permissions.find_by_name("Editor") || current_user.permissions.find_by_name("Admin"))
  end

  def current_user_is_pro
    current_user && current_user.permissions.find_by_name("Pro")
  end

  def is_editor_mode_enabled
    session[:edit_mode_enabled]
  end

  def google_drive_covid_documents_count
    google_drive_covid_data_json_path = 'public/google_drive_covid_data.json'
    google_drive_covid_files_count = 0
    if File.file?(google_drive_covid_data_json_path)
      file = File.read(google_drive_covid_data_json_path)
      data_hash = JSON.parse(file)
      google_drive_covid_files_count =  data_hash['file_count']
    end
    return google_drive_covid_files_count
  end

  def all_document_count
    Law.count + Document.count + google_drive_covid_documents_count
  end

  def get_fingerprint
    raw_fingerprint = request.remote_ip +
      browser.to_s +
      browser.device.name +
      browser.device.id.to_s +
      browser.platform.name
    hashed_fingerprint = BCrypt::Engine.hash_secret( raw_fingerprint, "$2a$10$ThisIsTheSalt22CharsX." )
    return hashed_fingerprint
  end
  def get_user_document_download_tracker(user_id_str)
    fingerprint = get_fingerprint + user_id_str
    user_document_download_tracker = UserDocumentDownloadTracker.find_by_fingerprint(fingerprint)
    if !user_document_download_tracker
      user_document_download_tracker = UserDocumentDownloadTracker.create(fingerprint: fingerprint, downloads: 0, period_start: DateTime.now)
    end
    if user_document_download_tracker.period_start <= 1.month.ago # TODO set time window
      user_document_download_tracker.period_start = DateTime.now
      user_document_download_tracker.downloads = 0
      user_document_download_tracker.save
    end
    return user_document_download_tracker
  end
  def can_access_documents(user_document_download_tracker, current_user_type)
    if current_user_type == "pro"
      return true
    elsif current_user_type == "basic"
      return user_document_download_tracker.downloads < MAXIMUM_BASIC_MONTHLY_DOCUMENTS
    else
      return user_document_download_tracker.downloads < MAXIMUM_NOT_LOGGGED_MONTHLY_DOCUMENTS
    end
  end
  def current_user_type user
    if user
      if !user.stripe_customer_id.blank?
        customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      end
      if (customer and current_user_plan_is_active customer) || (current_user_is_editor)
        return "pro"
      else
        return "basic"
      end
    end
    return "not logged"
  end

  def current_user_plan_is_active customer
    begin
      customer.subscriptions.data.each do |subscription|
        if subscription.plan.product == STRIPE_SUBSCRIPTION_PRODUCT and subscription.plan.active
          return true
        end
      end
    rescue
      puts "Todo: Handle Stripe customer error"
    end
    return false
  end

  def ley_abierta_url
    "https://pod.link/LeyAbierta/"
  end

  def non_pro_law_count
    todos_law_count = LawAccess.find_by_name("Todos").laws.count
    basica_law_count = LawAccess.find_by_name("Básica").laws.count
    return todos_law_count + basica_law_count
  end

  def maximum_basic_monthly_documents
    MAXIMUM_BASIC_MONTHLY_DOCUMENTS
  end

  def law_count
    Law.count
  end

  def valid_document_count
    Document.where.not(name: "Gaceta").count
  end

  def user_browser_language_is_english
    browser_locale = request.env['HTTP_ACCEPT_LANGUAGE'].try(:scan, /^[a-z]{2}/).try(:first) 
    return browser_locale.eql? "en"
  end
end
