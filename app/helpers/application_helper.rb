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

  def user_is_admin_api user
    user &&  user.permissions.find_by_name("Admin")
  end

  def user_is_editor_api user
    user && ( user.permissions.find_by_name("Editor") ||  user.permissions.find_by_name("Admin"))
  end

  def user_is_pro_api user
    user &&  user.permissions.find_by_name("Pro")
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
   return user_document_download_tracker
  end

  def can_access_documents(user)
    current_user_type = current_user_type_api(user)
    user_trial = nil
    if current_user_type != "not logged"
      user_trial = UserTrial.find_by(user_id: user.id)
    end

    if current_user_type == "pro"
      if !user_trial
        user_trial = UserTrial.create(user_id: user.id, active: false)
      end
      return true
    elsif current_user_type == "basic"
      if !user_trial
        user_trial = UserTrial.create(user_id: user.id, trial_start: DateTime.now, trial_end: DateTime.now + 2.weeks, active: true)
        NotificationsMailer.basic_with_active_notifications(user).deliver
        SubscriptionsMailer.free_trial_end(user).deliver_later(wait_until: user_trial.trial_end - 1.days)
        NotificationsMailer.cancel_notifications(user).deliver_later(wait_until: user_trial.trial_end)
      end
      return user_trial.active?
    else
      return false
    end
  end

  def remaining_free_trial_time user
    user_trial = UserTrial.find_by(user_id: user.id)
    trial_remaining_time = 0
    current_user_type = current_user_type_api(user)

    if current_user_type == "pro"
      return -1
    end

    if user_trial
      trial_remaining_time = user_trial.trial_end - user_trial.trial_start
      trial_remaining_time = (trial_remaining_time/1.day).to_i
    end

    return trial_remaining_time
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

  def current_user_type_api user
    if user
      if !user.stripe_customer_id.blank?
        customer = Stripe::Customer.retrieve(user.stripe_customer_id)
      end
      if (customer and current_user_plan_is_active customer) || (user_is_editor_api user) || (user_is_pro_api user)
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
    "https://leyabierta.todolegal.app/"
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

  def valid_gazettes_count
    Document.where.not(publication_number: nil).group_by(&:publication_number).count
  end

  def user_browser_language_is_english
    browser_locale = request.env['HTTP_ACCEPT_LANGUAGE'].try(:scan, /^[a-z]{2}/).try(:first) 
    return browser_locale.eql? "en"
  end

  def get_document_title document
    if !document.name.blank? and !document.issue_id.blank?
      return document.name + ", " + document.issue_id
    elsif !document.name.blank? and document.issue_id.blank?
      return document.name
    elsif document.name.blank? and !document.issue_id.blank?
      return document.issue_id
    else
      return "<vacío>"
    end
  end

  def form_url_field document
    if !document.url.blank?
      return document.url
    elsif !document.issue_id.blank?
      return I18n.transliterate(document.issue_id.gsub(/\s/, "-"))
    elsif !document.name.blank?
      return I18n.transliterate(document.name.gsub(/\s/, "-"))
    else
      return "documento"
    end
  end

  def enqueue_new_job user
    @user_preferences = UsersPreference.find_by(user_id: user.id)
    mail_frequency = @user_preferences.mail_frequency
    job = MailUserPreferencesJob.set(wait: @user_preferences.mail_frequency.minutes + 5.minutes).perform_later(user)
    @user_preferences.job_id = job.provider_job_id
    @user_preferences.save
  end

  def delete_user_notifications_job job_id
    if job_id
      job_to_delete = Sidekiq::ScheduledSet.new.find_job(job_id)
      return job_to_delete ? job_to_delete.delete : false
    end
    return false
  end

  def get_tags_name tags_ids
    tags_names = []

    tags_ids.each do |id|
        tag = Tag.find_by(id: id)
        if tag
            tags_names.push(tag.name)
        end
    end

    return tags_names
  end

  # def already_logged_in_helper
  #   Warden::Manager.after_set_user only: :fetch do |record, warden, options|
  #     scope = options[:scope]
  #     if record.devise_modules.include?(:session_limitable) && warden.authenticated?(scope) && options[:store] != false
  #     #Log Inicio
  #      if record.unique_session_id != warden.session(scope)['unique_session_id'] && !record.skip_session_limitable? &&  !warden.session(scope)['devise.skip_session_limitable']
  #       return true
  #      end
  #     end
  #   end
  #   return false
  # end

  #def send_confirmation_email
  #  current_user.send_confirmation_instructions
  #end

end
