require 'spec_helper'

TITLES = ['Broadband help', 'Speed up your internet', 'New channels available']
SLUGS = ['broadband-help', 'speed-up-your-internet', 'new-channels-available']
TAGS = ['TV', 'Broadband', 'Internet', 'Talk', 'Security', 'Account', 'Billing', 'Remote', 'Modem',
        'Microfilter', 'Browser', 'Device', 'Chat', 'Legal']

CONTENT = [
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Pellentesque mi turpis, aliquet ac laoreet sed, ullamcorper id metus. Duis ornare aliquam porta. Aliquam quis mattis arcu, sagittis pulvinar nulla. Maecenas vel enim at orci volutpat interdum ac in justo. Sed in placerat enim. Proin et risus gravida, tincidunt tellus quis, rutrum dolor. Nunc convallis dapibus nunc, in tincidunt orci vehicula posuere. Nulla elementum mattis lacus, a euismod eros tincidunt sed. Curabitur ipsum lectus, fringilla quis nulla vitae, tincidunt ultricies magna. Vestibulum sagittis metus eget neque commodo porta. Nam adipiscing ultrices leo quis hendrerit. Vivamus nec lacus ac enim viverra egestas. Praesent non placerat risus, eu mollis neque.',
  'Mauris viverra, mauris sed scelerisque suscipit, ipsum justo condimentum sem, vitae tincidunt augue dui gravida urna. Curabitur dui felis, consequat at placerat porttitor, gravida eu arcu. Integer sed metus posuere, dictum justo nec, luctus arcu. Nulla facilisi. Ut nunc sem, adipiscing vel fringilla ut, consequat sed orci. Cras ornare ullamcorper velit, at scelerisque dui suscipit eget. Sed consectetur nunc sed aliquet scelerisque. Nulla facilisi. Donec porta urna eu sapien pharetra sodales. In interdum nulla vel massa adipiscing, a tristique sem commodo. Nulla eu vehicula tellus, vel mollis arcu. Maecenas dictum nulla non magna scelerisque mollis. Nam aliquet blandit venenatis.',
  'Aliquam mollis lorem pretium odio volutpat, non pharetra risus malesuada. Donec eleifend nisl ut mi scelerisque, ut fringilla neque tristique. Cras blandit eu odio tincidunt faucibus. Nam molestie at lectus non tincidunt. Aliquam pretium ligula ac magna mattis tristique. Maecenas vehicula vitae tellus pellentesque tristique. Integer nec elit ligula. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Cras nisl purus, consequat quis turpis ut, sodales lobortis est. Duis semper, ligula ut malesuada sollicitudin, turpis tortor mattis purus, vel porttitor arcu erat placerat quam. Donec pretium diam purus, eu tincidunt libero congue quis. Pellentesque est ligula, tincidunt eu pretium a, imperdiet quis risus.',
  'Aliquam non diam non dolor gravida pharetra non et mi. Nam libero libero, commodo non tempus sit amet, consectetur vel sem. Vestibulum ut viverra nisl. Aenean auctor in magna et vestibulum. Aenean augue nulla, luctus nec elit dignissim, venenatis accumsan dolor. Duis sollicitudin neque ut lobortis varius. Proin sodales vitae dolor ut laoreet. Maecenas convallis augue sit amet libero dignissim, nec porttitor libero porta. Donec at orci sed est tempor facilisis. Vestibulum volutpat purus nec arcu aliquam sodales. Duis sagittis consectetur lorem, porttitor commodo neque sodales et. Praesent feugiat tellus sagittis, volutpat mauris vel, pharetra lorem. Curabitur purus magna, scelerisque et euismod congue, interdum non mauris. Morbi aliquet odio nisl, id dignissim libero lobortis ultricies. Nullam augue odio, faucibus vitae leo dignissim, malesuada porttitor enim. Quisque sit amet mauris quis arcu ornare fringilla.',
  'Etiam volutpat auctor erat, quis feugiat lacus luctus ac. Etiam eu mauris a tortor rutrum pellentesque. Curabitur tempus vulputate velit, fringilla dapibus lorem consequat non. Integer laoreet mauris ac tortor consequat blandit. Donec nec elementum eros, at commodo lorem. Donec at consectetur enim, vitae placerat sapien. Vivamus pellentesque augue sodales euismod laoreet. Suspendisse potenti. Aliquam erat volutpat. Donec eget ante enim. Fusce nibh sapien, pretium et venenatis sed, euismod nec tellus. Donec nec nulla tristique odio pretium placerat eu et nisi.',
  'In hac habitasse platea dictumst. Pellentesque pretium ultrices orci et accumsan. Curabitur ut magna in turpis scelerisque pretium. Aenean lacinia eros vel arcu tempus consectetur. Vestibulum rutrum, nunc a laoreet consequat, turpis dui convallis nisi, sit amet vulputate magna nulla sed nisi. Vivamus posuere, risus et commodo vestibulum, neque dui vestibulum urna, ut mattis purus diam ut sapien. Quisque non sem et enim dictum sodales. Praesent iaculis at nulla eu semper. Proin vel quam eros. Duis ornare elit a ligula tincidunt posuere. Curabitur elit eros, sollicitudin at elit non, pellentesque condimentum ipsum. Donec a libero in sapien lobortis rutrum. Maecenas aliquam mauris vitae pretium porta. Duis suscipit, orci sit amet dictum fermentum, lacus mi elementum tortor, in vulputate diam justo vitae orci.',
  'Vivamus ac lacus in tortor bibendum iaculis posuere vitae mauris. Mauris semper laoreet tellus non ultricies. Pellentesque habitant morbi tristique senectus et netus et malesuada fames ac turpis egestas. Phasellus tempus lobortis dui sagittis mollis. Maecenas adipiscing sed orci in ultricies. Sed fermentum diam leo, quis egestas dolor hendrerit id. Ut porta eros et neque auctor gravida eget et lectus. Vestibulum iaculis, ligula a tempor lacinia, est nibh facilisis mauris, sagittis sollicitudin diam sem non risus. Suspendisse sagittis ipsum nunc, eget dignissim sem faucibus eget. Cras faucibus vulputate tellus eget semper. Praesent a tempor felis, eget consequat nibh. Praesent dui arcu, sollicitudin sed fringilla vitae, sagittis eu urna.',
  'Curabitur euismod leo nec odio sollicitudin, in tempus enim pretium. Etiam tempor orci at quam ultrices congue. Quisque vel libero mauris. Etiam porta odio eget metus commodo ornare. Sed quam dui, fermentum ut velit eu, faucibus tristique nisl. Vivamus ut volutpat enim. Vestibulum libero mauris, placerat eget odio eget, volutpat commodo nunc. Sed dolor sapien, viverra at dui eget, aliquam vulputate dolor. In sapien tortor, viverra at aliquam eu, aliquet a magna. Nulla nec consectetur leo. Etiam eget ultrices eros. Donec lorem libero, sagittis nec quam a, feugiat euismod magna. Praesent ut tempus quam. Nullam sodales faucibus nulla, ac tempor mi tempus sit amet.',
  'Suspendisse molestie diam mauris, non auctor dolor interdum at. Etiam ut volutpat nibh. Curabitur vestibulum in sem at varius. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Etiam vitae viverra nunc, ac facilisis tortor. Etiam venenatis ac nisl non mattis. Duis a massa et erat auctor rutrum. Nunc sodales semper dolor, eu suscipit lorem eleifend congue. Etiam tortor mi, auctor non gravida sed, laoreet id eros.',
  'Duis mauris leo, facilisis id pulvinar vel, elementum sed ante. Nullam fringilla vel magna sed dignissim. Mauris tincidunt nibh orci, quis facilisis turpis gravida eu. Sed bibendum odio lacus. Vivamus ac sollicitudin arcu, at euismod urna. Ut hendrerit purus magna, at volutpat augue accumsan ac. Integer egestas orci est, nec tempus leo euismod at. Etiam accumsan arcu quis neque lacinia tempor. Donec vitae neque orci. Quisque dolor dui, accumsan at mauris et, ornare porta est. Ut dignissim sit amet nibh quis convallis. Aenean varius tristique justo sit amet fringilla. Integer diam dui, fermentum in tortor vehicula, scelerisque ornare ipsum. Donec tincidunt suscipit enim id mollis. Suspendisse faucibus consectetur fringilla.',
  'Vestibulum ut ultricies nulla, nec suscipit augue. Suspendisse mi dui, tempor sit amet iaculis ac, vestibulum a risus. Cras viverra placerat odio a interdum. Vivamus euismod dui a magna aliquet congue. Mauris fringilla erat eget ipsum egestas, ac iaculis ante pharetra. Nunc sit amet sagittis neque. Morbi vel placerat elit. Fusce fermentum dolor ac tincidunt blandit. Curabitur condimentum neque orci, ac venenatis mi mollis non. Ut aliquet ornare ante, id fringilla risus ultrices non.',
  'Integer bibendum pellentesque condimentum. In mauris enim, vestibulum vel nunc quis, tincidunt tincidunt sem. Ut vel elit vel quam vehicula dapibus a sit amet nulla. Ut porttitor aliquet ultrices. Vivamus a eros consequat, mollis orci ut, tempus eros. Fusce eu diam velit. Donec rutrum fermentum blandit. In nec bibendum ante, in porttitor lacus. Duis quis eros viverra, fermentum augue in, facilisis augue. Fusce non enim tristique lacus viverra blandit at nec arcu.',
  'Proin luctus velit sodales ante rutrum facilisis. Sed ut diam a erat gravida pharetra. Vestibulum dolor nulla, ultrices ut eros ut, aliquet fringilla orci. Suspendisse potenti. Proin lacinia scelerisque justo ac interdum. In eleifend vestibulum massa in facilisis. Aliquam condimentum velit vel dui consectetur, in commodo lacus sodales. Nunc ac libero ac massa fringilla egestas eget a orci. Suspendisse pretium dolor est, eu varius odio rutrum vitae.',
  'Ut sit amet massa volutpat, viverra urna a, faucibus tellus. Aenean pulvinar consequat viverra. Morbi auctor dui nec nibh lacinia, condimentum ornare sem vehicula. Aenean vulputate erat ut libero lobortis, nec accumsan lacus sagittis. Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Morbi congue semper facilisis. Nam ac lacinia nibh.',
  'Cum sociis natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Pellentesque dignissim lorem a lacinia tempor. Vestibulum ac tincidunt augue. Vestibulum feugiat accumsan nisi at tincidunt. Vestibulum tincidunt nisl et pellentesque dictum. Ut eu orci elit. Phasellus ac mauris risus. In ultrices, sapien nec vehicula vulputate, dolor eros pharetra sem, eu ullamcorper sapien ligula ac sapien. Phasellus dictum adipiscing eros non sagittis. Fusce luctus velit eget justo tempus porttitor. Pellentesque laoreet ut sem non tincidunt. In hac habitasse platea dictumst. Nunc vulputate, lectus ut molestie rhoncus, libero tortor ultrices ante, in convallis risus neque ac orci. Proin sed enim porttitor, accumsan massa in, faucibus nibh. Ut lacinia eleifend mi. Pellentesque dignissim libero vitae pretium egestas.',
  'Donec ut purus sagittis, ultricies lorem eget, euismod erat. Nunc tincidunt ullamcorper massa id bibendum. Ut dictum volutpat urna, vitae fringilla leo consectetur ac. In pulvinar congue gravida. Vivamus in magna nunc. Sed ut ligula elit. Proin blandit tristique lorem id faucibus. Sed enim urna, rhoncus ut massa eu, feugiat blandit mi. Aliquam laoreet nibh a nisl cursus rhoncus. Duis luctus eros at tempus aliquam. Mauris hendrerit non ipsum quis venenatis. Sed ullamcorper felis aliquam urna lobortis, id porttitor elit posuere. Maecenas nec pulvinar metus. Morbi in augue nisl. Sed et tincidunt massa. Aliquam vitae nibh magna.',
  'Nulla vitae lobortis nisl, et gravida dolor. Morbi pellentesque metus ac lobortis tempor. Sed ut ipsum malesuada, convallis lacus in, commodo mi. Nulla gravida nibh id ante luctus, quis aliquet massa luctus. In feugiat lacus quis convallis dictum. In congue lobortis elit, eu condimentum libero consectetur sed. Cras at ornare arcu. Proin porttitor tincidunt ligula, et pellentesque mi tempor aliquam. Pellentesque gravida mi a velit dapibus, eu auctor erat suscipit. Quisque tempus massa ut justo sagittis congue.',
  'Suspendisse eget mauris nec nulla hendrerit tempor vitae non augue. Curabitur quis mattis neque. Duis commodo aliquet elit, quis interdum ligula porta a. Integer sapien nulla, varius vel auctor molestie, rutrum quis nisl. Proin mollis, urna ut tempus imperdiet, nibh mauris fringilla mauris, vel varius diam tellus quis velit. Suspendisse laoreet nibh vel nibh tincidunt auctor vitae sed nisl. Mauris ornare porta mauris, placerat dignissim ante blandit nec. Cras vitae mauris vel purus fermentum fringilla sit amet eu lorem. Cras leo purus, sollicitudin at sapien vitae, tristique blandit nisl. Sed posuere, augue eu interdum luctus, turpis lacus commodo felis, vitae volutpat eros lorem eu metus. Nulla rutrum congue scelerisque. Duis tristique justo ante, at luctus ipsum mollis sed. Maecenas sit amet ante ut erat semper dignissim.',
  'Quisque sit amet dignissim est. Interdum et malesuada fames ac ante ipsum primis in faucibus. Pellentesque non urna lectus. Donec lobortis justo turpis, at posuere sapien consectetur porta. Integer rutrum dignissim scelerisque. Integer eleifend rhoncus lorem, et rutrum mauris tincidunt ut. Sed sapien turpis, ultricies id tellus at, luctus feugiat sem. Mauris lacus ipsum, dapibus nec rutrum non, gravida dignissim nulla. Sed ornare ipsum id tellus viverra, in pretium leo eleifend.',
  'Nam sit amet nibh id turpis placerat pretium. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Cras posuere aliquet lectus, non egestas diam aliquam quis. Nunc gravida nulla id mi tristique suscipit. Donec eleifend nibh non nisl pulvinar egestas. Aenean condimentum vulputate purus eu pulvinar. Nulla laoreet ut eros at eleifend. Nulla eu massa a ligula ornare pretium at sed tellus. Quisque convallis, dui ut feugiat cursus, lectus justo rutrum mauris, id pharetra metus odio commodo tortor. Aliquam ultricies tellus pharetra velit ultrices pharetra. Sed quis euismod nisl. Nulla sit amet ultrices massa, in viverra enim. Nulla venenatis turpis lacus, at aliquam est hendrerit nec.'
]

describe "Stress test", live: true do
  before do
    Colonel.config.storage_path = 'tmp/integration_test'

    ContentItem.ensure_index!
    ContentItem.put_mapping!
  end

  it "should create a 100 documents without a hitch" do
    doc_ids = []

    expect do
      docs = (1..100).to_a.map do |i|
        info = {
          title: TITLES.sample(1).first,
          tags: TAGS.sample(5),
          slug: "#{SLUGS.sample(1).first}_#{i}",
          abstract: CONTENT.sample(1).first,
          body: CONTENT.sample(4).flatten.join("\n\n")
        }

        doc = ContentItem.new(info)
        doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

        doc_ids << doc.id

        doc.body += CONTENT.sample(1).first
        doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

        doc.tags += TAGS.sample(2)

        doc.save!({name: "John Doe", email: "john@example.com"}, "Commit message")

        doc
      end

      docs.sample(30).each do |doc|
        doc.publish!
      end

      docs.sample(50).each do |doc|
        doc.tags = doc.tags.sample(5)

        doc.save!({name: "John Doe", email: "john@example.com"}, "Another commit message")
      end

      docs.select {|d| !d.most_recent_published? }.sample(20).each do |doc|
        doc.publish!
      end

      docs.sample(40).each do |doc|
        doc.title += " (updated)"

        doc.save
      end

      puts "Generated #{docs.length} documents.\n"
    end.not_to raise_error

    doc_ids.each do |id|
      doc = ContentItem.open(id)

      expect(TITLES).to include(doc.title)
    end
  end
end
