# frozen_string_literal: true

RSpec.describe EventStoreClient::Mapper::Encrypted do
  let(:data) do
    {
      'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
      'first_name' => 'Anakin',
      'last_name' => 'Skywalker',
      'profession' => 'Jedi'
    }
  end

  describe '#serialize' do
    subject { described_class.new(DummyRepository.new).serialize(user_registered) }

    let(:encrypted_data) do
      {
        'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        'first_name' => 'es_encrypted',
        'last_name' => 'es_encrypted',
        'profession' => 'Jedi',
        'es_encrypted' => DummyRepository.encrypt(data.slice('first_name', 'last_name').to_json)
      }
    end
    let(:user_registered) { EncryptedEvent.new(data: data) }

    it 'returns serialized event' do
      expect(subject).to be_kind_of(EventStoreClient::Event)
      expect(subject.data).to eq(JSON.generate(encrypted_data))
      expect(subject.metadata).to include('created_at')
      expect(subject.metadata).to include('encryption')
      expect(subject.type).to eq('EncryptedEvent')
    end

    context 'when event is a link' do
      let(:user_registered) { EncryptedEvent.new(data: data, type: '$>') }

      it 'does not encrypt its data' do
        expect(subject.data).to eq(JSON.generate(data))
      end
    end
  end

  describe '#deserialize' do
    subject { described_class.new(DummyRepository.new).deserialize(user_registered) }

    let(:encryption_metadata) do
      {
        iv: 'DarthSidious',
        key: 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        attributes: %i[first_name last_name]
      }
    end
    let(:encrypted_data) do
      {
        'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        'first_name' => 'es_encrypted',
        'last_name' => 'es_encrypted',
        'profession' => 'Jedi',
        'es_encrypted' => DummyRepository.encrypt(message_to_encrypt)
      }
    end
    let(:decrypted_data) do
      {
        'user_id' => 'dab48d26-e4f8-41fc-a9a8-59657e590716',
        'first_name' => 'Anakin',
        'last_name' => 'Skywalker',
        'profession' => 'Jedi'
      }
    end
    let(:user_registered) do
      EventStoreClient::Event.new(
        data: encrypted_data.to_json,
        metadata: { encryption: encryption_metadata }.to_json,
        type: 'EncryptedEvent'
      )
    end
    let(:message_to_encrypt) do
      decrypted_data.slice('first_name', 'last_name').to_json
    end

    before do
      DummyRepository.new.encrypt(
        key: DummyRepository::Key.new(id: decrypted_data['user_id']),
        message: message_to_encrypt
      )
      allow(EncryptedEvent).to receive(:new).and_call_original
    end

    it 'returns deserialized event' do
      expect(subject).to be_kind_of(EncryptedEvent)
      expect(subject.data).to eq(decrypted_data)
      expect(subject.metadata).to include('created_at')
      expect(subject.data).not_to include('es_encrypted')
    end
    it 'skips validation' do
      subject
      expect(EncryptedEvent).to have_received(:new).with(hash_including(skip_validation: true))
    end
  end
end
